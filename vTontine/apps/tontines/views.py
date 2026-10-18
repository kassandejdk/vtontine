from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.shortcuts import get_object_or_404
from django.conf import settings
from django.db import models
from django.utils import timezone
import uuid
from .models import (
    Tontine, DemandeAdhesion, Participation, RegleTontine,
    InvitationTontine, MessageTontine, MethodePaiement, Cycle,
)
from apps.users.models import User
from apps.notifications.models import Notification
from . import services
from .serializers import (
    TontineSerializer,
    TontineCreateSerializer,
    TontineUpdateSerializer,
    ParticipationSerializer,
    DemandeAdhesionSerializer,
    DemandeAdhesionListSerializer,
    RegleTontineSerializer,
    RegleTontineWriteSerializer,
    InvitationRecueSerializer,
    MessageTontineSerializer,
    MethodePaiementSerializer,
    CycleSerializer,
    UserMinimalSerializer,
)


class TontineListCreateView(APIView):
   
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Récupérer les tontines où l'user est créateur OU participant
        tontines_creees = Tontine.objects.filter(createur=request.user)
        tontines_participees = Tontine.objects.filter(
            participations__participant=request.user,
            participations__statut__in=['EN_ATTENTE', 'CONFIRME'],
        )
        # Fusionner sans doublons
        tontines = (tontines_creees | tontines_participees).distinct()

        # Filtrer par statut si demandé
        statut = request.query_params.get('statut')
        if statut:
            tontines = tontines.filter(statut=statut)

        serializer = TontineSerializer(
            tontines, many=True, context={'request': request}
        )
        return Response(serializer.data)

    def post(self, request):
        serializer = TontineCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        # Le créateur = l'utilisateur connecté.
        # NB : si createur_est_membre est True, la participation du créateur est
        # créée automatiquement par Tontine.save() (cf. models.py) — ne pas la
        # recréer ici sous peine d'IntegrityError (unique_together tontine/participant).
        tontine = serializer.save(createur=request.user)

        return Response(
            TontineSerializer(tontine, context={'request': request}).data,
            status=status.HTTP_201_CREATED
        )

class TontineDetailView(APIView):
   
    permission_classes = [IsAuthenticated]

    def get_tontine(self, tontine_id, user=None, check_createur=False):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if check_createur and tontine.createur != user:
            return None, Response(
                {'error': 'Seul le créateur peut effectuer cette action'},
                status=status.HTTP_403_FORBIDDEN
            )
        return tontine, None

    def get(self, request, tontine_id):
        tontine, error = self.get_tontine(tontine_id)
        if error:
            return error
        serializer = TontineSerializer(tontine, context={'request': request})
        return Response(serializer.data)

    def put(self, request, tontine_id):
        tontine, error = self.get_tontine(
            tontine_id, user=request.user, check_createur=True
        )
        if error:
            return error

        serializer = TontineUpdateSerializer(
            tontine, data=request.data, partial=True
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        tontine = serializer.save()
        return Response(TontineSerializer(tontine, context={'request': request}).data)

    def delete(self, request, tontine_id):
        tontine, error = self.get_tontine(
            tontine_id, user=request.user, check_createur=True
        )
        if error:
            return error

        if tontine.statut in ('COMPLET', 'TERMINE'):
            return Response(
                {'error': 'Impossible de supprimer une tontine complète ou terminée'},
                status=status.HTTP_400_BAD_REQUEST
            )

        tontine.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

class TontineParticipantsView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        participations = tontine.participations.select_related('participant').all()
        serializer = ParticipationSerializer(participations, many=True)
        return Response(serializer.data)

class DecouvrirTontinesView(APIView):
    """
    GET /api/tontines/decouvrir/
    Tontines publiques que l'utilisateur n'a pas encore créées ni rejointes.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        tontines = Tontine.objects.filter(
            visibilite=True, statut='INCOMPLET'
        ).exclude(
            createur=request.user
        ).exclude(
            participations__participant=request.user
        ).exclude(
            # Masquer les tontines où j'ai déjà une demande d'adhésion en attente
            demandes__demandeur=request.user, demandes__statut='EN_ATTENTE'
        ).distinct()

        serializer = TontineSerializer(
            tontines, many=True, context={'request': request}
        )
        return Response(serializer.data)

class OrdrePriseView(APIView):
    """
    PATCH /api/tontines/<tontine_id>/participants/<participation_id>/ordre/
    Réservé au créateur : modifie manuellement l'ordre de passage d'un participant.
    """
    permission_classes = [IsAuthenticated]

    def patch(self, request, tontine_id, participation_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if tontine.createur != request.user:
            return Response(
                {'error': 'Seul le créateur peut modifier l\'ordre de passage'},
                status=status.HTTP_403_FORBIDDEN
            )

        participation = get_object_or_404(
            Participation, id=participation_id, tontine=tontine
        )

        ordre = request.data.get('ordre_prise')
        if ordre is None or int(ordre) < 1:
            return Response(
                {'error': 'Le champ "ordre_prise" (entier >= 1) est requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        participation.ordre_prise = int(ordre)
        participation.save(update_fields=['ordre_prise'])
        return Response(ParticipationSerializer(participation).data)

class TerminerTontineView(APIView):
    """
    POST /api/tontines/<tontine_id>/terminer/
    Réservé au créateur : clôture définitivement le cycle de la tontine.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if tontine.createur != request.user:
            return Response(
                {'error': 'Seul le créateur peut terminer la tontine'},
                status=status.HTTP_403_FORBIDDEN
            )

        if tontine.statut == 'TERMINE':
            return Response(
                {'error': 'Cette tontine est déjà terminée'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Terminaison restreinte : on ne peut clôturer qu'une fois toutes les
        # prises attribuées effectivement versées à leurs bénéficiaires.
        services.generer_cycles(tontine)
        bloquants = services.cycles_non_soldes(tontine)
        if bloquants:
            tours = ', '.join(str(c.numero) for c in bloquants)
            return Response(
                {'error': (
                    "Impossible de terminer : la prise n'a pas encore été versée "
                    f"pour le(s) tour(s) {tours}. Verse toutes les prises dans "
                    "« Suivi des cycles » avant de clôturer."
                )},
                status=status.HTTP_400_BAD_REQUEST,
            )

        tontine.statut = 'TERMINE'
        tontine.save(update_fields=['statut'])
        return Response(TontineSerializer(tontine, context={'request': request}).data)

class ExclureParticipantView(APIView):
    """
    POST /api/tontines/<tontine_id>/participants/<participation_id>/exclure/
    Réservé au créateur : exclut un participant qui ne respecte pas les règles.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, tontine_id, participation_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if tontine.createur != request.user:
            return Response(
                {'error': 'Seul le créateur peut exclure un participant'},
                status=status.HTTP_403_FORBIDDEN
            )

        participation = get_object_or_404(
            Participation, id=participation_id, tontine=tontine
        )

        if participation.est_createur:
            return Response(
                {'error': 'Le créateur ne peut pas s\'exclure lui-même'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if participation.statut == 'EXCLU':
            return Response(
                {'error': 'Ce participant est déjà exclu'},
                status=status.HTTP_400_BAD_REQUEST
            )

        motif = request.data.get('motif', '').strip()
        participation.statut = 'EXCLU'
        participation.ordre_prise = None
        participation.save(update_fields=['statut', 'ordre_prise'])
        tontine.recalculer_statut()

        message = f'Vous avez été exclu(e) de la tontine "{tontine.nom}".'
        if motif:
            message += f' Motif : {motif}'

        Notification.objects.create(
            user=participation.participant,
            titre='Exclusion de la tontine',
            message=message,
        )

        return Response(ParticipationSerializer(participation).data)

class QuitterTontineView(APIView):
    """
    DELETE /api/tontines/<tontine_id>/quitter/
    Un membre quitte volontairement une tontine encore en recrutement.
    Le créateur ne peut pas quitter (il doit terminer ou supprimer la tontine).
    """
    permission_classes = [IsAuthenticated]

    def delete(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)

        if tontine.createur_id == request.user.id:
            return Response(
                {'error': 'Le créateur ne peut pas quitter sa propre tontine.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if tontine.statut in ('COMPLET', 'TERMINE'):
            return Response(
                {'error': 'Impossible de quitter une tontine complète ou terminée.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        participation = Participation.objects.filter(
            tontine=tontine, participant=request.user,
            statut__in=['EN_ATTENTE', 'CONFIRME'],
        ).first()
        if not participation:
            return Response(
                {'error': 'Vous ne participez pas à cette tontine.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        participation.delete()
        tontine.recalculer_statut()
        return Response(status=status.HTTP_204_NO_CONTENT)


class RejoindreViaInvitationView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request, token):
        """Prévisualise la tontine ciblée par un jeton (deep link), sans rejoindre."""
        try:
            tontine = services.infos_invitation(token)
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_404_NOT_FOUND)
        return Response(
            TontineSerializer(tontine, context={'request': request}).data
        )

    def post(self, request, token):
        regles_ids = request.data.get('regles_acceptees', [])

        try:
            participation = services.rejoindre_via_invitation(
                user=request.user,
                token=token,
                regles_ids=regles_ids,
            )
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(
            ParticipationSerializer(participation).data,
            status=status.HTTP_201_CREATED
        )

class RefuserInvitationView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request, token):
        try:
            invitation = services.refuser_invitation(user=request.user, token=token)
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response({'message': 'Invitation refusée.', 'statut': invitation.statut})

class DemandeAdhesionView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if tontine.createur != request.user:
            return Response(
                {'error': 'Seul le créateur peut voir les demandes d\'adhésion'},
                status=status.HTTP_403_FORBIDDEN
            )
        demandes = tontine.demandes.filter(statut='EN_ATTENTE')
        return Response(DemandeAdhesionListSerializer(demandes, many=True).data)

    def post(self, request, tontine_id):
        tontine    = get_object_or_404(Tontine, id=tontine_id)
        message    = request.data.get('message', '')
        regles_ids = request.data.get('regles_acceptees', [])

        try:
            demande = services.soumettre_demande_adhesion(
                user=request.user,
                tontine=tontine,
                message=message,
                regles_ids=regles_ids,
            )
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(
            DemandeAdhesionSerializer(demande).data,
            status=status.HTTP_201_CREATED
        )

class TraiterDemandeAdhesionView(APIView):
    
    permission_classes = [IsAuthenticated]

    def patch(self, request, demande_id):
        demande = get_object_or_404(DemandeAdhesion, id=demande_id)
        accepter = request.data.get('accepter')

        if accepter is None:
            return Response(
                {'error': 'Le champ "accepter" (true/false) est requis.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            demande = services.traiter_demande_adhesion(
                createur=request.user,
                demande=demande,
                accepter=bool(accepter),
            )
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(DemandeAdhesionListSerializer(demande).data)

class MesTontinesView(APIView):
    """
    GET /api/tontines/mes-tontines/
    Tontines de l'utilisateur : celles qu'il a créées ET celles où il participe.
    (Même périmètre que GET /api/tontines/ — conservé pour compatibilité.)
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        tontines = Tontine.objects.filter(
            models.Q(createur=request.user)
            | models.Q(
                participations__participant=request.user,
                participations__statut__in=['EN_ATTENTE', 'CONFIRME'],
            )
        ).distinct()
        serializer = TontineSerializer(
            tontines, many=True, context={'request': request}
        )
        return Response(serializer.data)
    
class GenererLienInvitationView(APIView):
    """
    POST /api/tontines/<tontine_id>/invitations/lien/
    Génère un lien d'invitation *partageable* (WhatsApp/SMS...), non rattaché à
    un compte : toute personne ayant le lien pourra rejoindre la tontine
    (après installation de l'app si besoin, puis acceptation des règles).
    Réservé au créateur.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)

        if tontine.createur != request.user:
            return Response(
                {'error': 'Seul le créateur peut générer un lien'},
                status=status.HTTP_403_FORBIDDEN
            )

        lien = services.generer_lien_partage(tontine, request.user)
        lien_web = f"{settings.FRONTEND_URL}/rejoindre/{lien.token}"

        return Response({
            'lien_web': lien_web,
            'token': str(lien.token),
            'expire_le': lien.expire_le,
        })

class RechercherUserParTelephoneView(APIView):
   
    permission_classes = [IsAuthenticated]

    def get(self, request, tontine_id):
        telephone = request.query_params.get('telephone', '').strip()

        if not telephone:
            return Response(
                {'error': 'Le paramètre "telephone" est requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = User.objects.filter(telephone=telephone).first()

        if user:
            return Response({
                'existe': True,
                'user': {
                    'id': user.id,
                    'nom': f"{user.prenom} {user.nom}".strip(),
                    'telephone': telephone,
                }
            })
        else:
            return Response({'existe': False})

class InviterParTelephoneView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        telephone = request.data.get('telephone', '').strip()

        if not telephone:
            return Response(
                {'error': 'Le champ "telephone" est requis'},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = User.objects.filter(telephone=telephone).first()
        if not user:
            return Response(
                {'error': 'Aucun compte trouvé avec ce numéro'},
                status=status.HTTP_404_NOT_FOUND
            )

        if Participation.objects.filter(
            tontine=tontine, participant=user, statut__in=['EN_ATTENTE', 'CONFIRME']
        ).exists():
            return Response(
                {'error': 'Cet utilisateur est déjà membre de la tontine'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            invitation = services.inviter_ou_reinviter(tontine, request.user, user)
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        # Crée la notification pour l'invité
        Notification.objects.create(
            user=user,
            titre='Invitation à une tontine',
            message=(
                f'{request.user.prenom} {request.user.nom} vous invite à rejoindre '
                f'la tontine "{tontine.nom}".'
            ),
            tontine=tontine,
            invitation_token=invitation.token,
        )

        return Response({
            'message': f'Invitation envoyée à {user.prenom} {user.nom}',
            'token': str(invitation.token),
        })


class RegleListCreateView(APIView):
    """
    GET  /api/tontines/<tontine_id>/regles/ → liste des règles (public/membre).
    POST /api/tontines/<tontine_id>/regles/ → ajouter une règle (créateur uniquement).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        regles = tontine.regles.all()
        return Response(RegleTontineSerializer(regles, many=True).data)

    def post(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if tontine.createur != request.user:
            return Response(
                {'error': 'Seul le créateur peut ajouter une règle'},
                status=status.HTTP_403_FORBIDDEN
            )

        serializer = RegleTontineWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(tontine=tontine)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class RegleDetailView(APIView):
    """
    PUT/PATCH /api/tontines/<tontine_id>/regles/<regle_id>/ → modifier (créateur).
    DELETE    /api/tontines/<tontine_id>/regles/<regle_id>/ → supprimer (créateur).
    """
    permission_classes = [IsAuthenticated]

    def _get_regle(self, request, tontine_id, regle_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if tontine.createur != request.user:
            return None, Response(
                {'error': 'Seul le créateur peut modifier les règles'},
                status=status.HTTP_403_FORBIDDEN
            )
        regle = get_object_or_404(RegleTontine, id=regle_id, tontine=tontine)
        return regle, None

    def put(self, request, tontine_id, regle_id):
        regle, error = self._get_regle(request, tontine_id, regle_id)
        if error:
            return error
        serializer = RegleTontineWriteSerializer(regle, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    def patch(self, request, tontine_id, regle_id):
        return self.put(request, tontine_id, regle_id)

    def delete(self, request, tontine_id, regle_id):
        regle, error = self._get_regle(request, tontine_id, regle_id)
        if error:
            return error
        regle.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class InvitationsRecuesView(APIView):
    """
    GET /api/tontines/invitations/ → invitations directes reçues par l'utilisateur.
        ?statut=EN_ATTENTE pour filtrer (par défaut : toutes).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        invitations = InvitationTontine.objects.filter(
            invite=request.user
        ).select_related('tontine', 'invite_par').order_by('-date_envoi')

        statut = request.query_params.get('statut')
        if statut:
            invitations = invitations.filter(statut=statut)

        return Response(
            InvitationRecueSerializer(
                invitations, many=True, context={'request': request}
            ).data
        )


class MethodePaiementListCreateView(APIView):
    """
    GET  /api/tontines/<id>/methodes-paiement/ → moyens de paiement (tous).
    POST /api/tontines/<id>/methodes-paiement/ → en ajouter un (créateur).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        methodes = tontine.methodes_paiement.all()
        return Response(MethodePaiementSerializer(methodes, many=True).data)

    def post(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if tontine.createur != request.user:
            return Response(
                {'error': 'Seul le créateur peut ajouter un moyen de paiement'},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = MethodePaiementSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(tontine=tontine)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class MethodePaiementDetailView(APIView):
    """DELETE /api/tontines/<id>/methodes-paiement/<mid>/ (créateur)."""
    permission_classes = [IsAuthenticated]

    def delete(self, request, tontine_id, methode_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if tontine.createur != request.user:
            return Response(
                {'error': 'Seul le créateur peut supprimer un moyen de paiement'},
                status=status.HTTP_403_FORBIDDEN,
            )
        methode = get_object_or_404(MethodePaiement, id=methode_id, tontine=tontine)
        methode.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MessagesTontineView(APIView):
    """
    GET  /api/tontines/<id>/messages/          → messages de la discussion (membres).
         /api/tontines/<id>/messages/?after=<id> → seulement les nouveaux (polling).
    POST /api/tontines/<id>/messages/          → envoyer un message (membres).
         Accepte du JSON (texte) ou du multipart (image / note vocale via
         'piece_jointe' + 'type').
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def _a_acces(self, tontine, user):
        return tontine.createur_id == user.id or Participation.objects.filter(
            tontine=tontine, participant=user, statut='CONFIRME'
        ).exists()

    def get(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if not self._a_acces(tontine, request.user):
            return Response(
                {'error': "Réservé aux membres de la tontine."},
                status=status.HTTP_403_FORBIDDEN,
            )
        messages = tontine.messages.select_related('auteur')
        after = request.query_params.get('after')
        if after:
            messages = messages.filter(id__gt=after)
        return Response(
            MessageTontineSerializer(
                messages, many=True, context={'request': request}
            ).data
        )

    def post(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if not self._a_acces(tontine, request.user):
            return Response(
                {'error': "Réservé aux membres de la tontine."},
                status=status.HTTP_403_FORBIDDEN,
            )
        contenu = (request.data.get('contenu') or '').strip()
        piece = request.FILES.get('piece_jointe')
        type_msg = request.data.get('type', 'TEXTE')
        if type_msg not in dict(MessageTontine.TYPE_CHOICES):
            type_msg = 'TEXTE'

        if not contenu and not piece:
            return Response(
                {'error': 'Message vide.'}, status=status.HTTP_400_BAD_REQUEST
            )
        if piece and type_msg == 'TEXTE':
            type_msg = 'IMAGE'  # sécurité : un fichier sans type explicite → image

        msg = MessageTontine.objects.create(
            tontine=tontine, auteur=request.user,
            contenu=contenu, type=type_msg, piece_jointe=piece,
        )
        return Response(
            MessageTontineSerializer(msg, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )


class CyclesRegistreView(APIView):
    """
    GET /api/tontines/<tontine_id>/cycles/
    Registre transparent des tours, accessible au créateur ET aux membres
    confirmés. Pour chaque cycle : dates, bénéficiaire, prise versée ou non,
    et pour chaque membre s'il est à jour de sa cotisation.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, tontine_id):
        tontine = get_object_or_404(Tontine, id=tontine_id)

        est_createur = tontine.createur_id == request.user.id
        est_membre = tontine.participations.filter(
            participant=request.user, statut='CONFIRME'
        ).exists()
        if not (est_createur or est_membre):
            return Response(
                {'error': "Réservé au créateur et aux membres de la tontine."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # (Re)génère les cycles pour refléter participants/dates à jour.
        services.generer_cycles(tontine)
        cycles = list(
            tontine.cycles.select_related('beneficiaire', 'beneficiaire__participant')
            .order_by('numero')
        )
        courant = services.cycle_courant(tontine)
        courant_id = courant.id if courant else None

        participations = list(
            tontine.participations.filter(statut='CONFIRME')
            .select_related('participant').order_by('ordre_prise', 'date_adhesion')
        )

        from apps.paiements.models import Paiement
        payes = set(
            Paiement.objects.filter(
                participation__tontine=tontine, statut='CONFIRME',
                cycle__isnull=False,
            ).values_list('cycle_id', 'participation_id')
        )

        cycles_data = []
        for c in cycles:
            base = CycleSerializer(c).data
            membres = []
            nb_a_jour = 0
            for p in participations:
                a_jour = (c.id, p.id) in payes
                if a_jour:
                    nb_a_jour += 1
                membres.append({
                    'participation_id': p.id,
                    'participant': UserMinimalSerializer(p.participant).data,
                    'ordre_prise': p.ordre_prise,
                    'est_createur': p.est_createur,
                    'est_beneficiaire': c.beneficiaire_id == p.id,
                    'a_jour': a_jour,
                })
            base['est_courant'] = c.id == courant_id
            base['membres'] = membres
            base['nb_a_jour'] = nb_a_jour
            base['nb_total'] = len(participations)
            cycles_data.append(base)

        return Response({
            'tontine_id': tontine.id,
            'montant': tontine.montant,
            'frequence_display': tontine.frequence_display,
            'est_createur': est_createur,
            'cycle_courant': courant.numero if courant else None,
            'cycles': cycles_data,
        })


class VerserPriseView(APIView):
    """
    POST /api/tontines/<tontine_id>/cycles/<numero>/verser-prise/
    Réservé au créateur : atteste que la prise du cycle a été remise au
    bénéficiaire, clôture le cycle et notifie le bénéficiaire.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, tontine_id, numero):
        tontine = get_object_or_404(Tontine, id=tontine_id)
        if tontine.createur_id != request.user.id:
            return Response(
                {'error': 'Seul le créateur peut verser une prise.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        services.generer_cycles(tontine)
        cycle = get_object_or_404(Cycle, tontine=tontine, numero=numero)

        if cycle.prise_versee:
            return Response(
                {'error': 'La prise de ce cycle est déjà versée.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        cycle.prise_versee = True
        cycle.date_versement = timezone.now()
        cycle.statut = 'CLOTURE'
        cycle.save(update_fields=['prise_versee', 'date_versement', 'statut'])

        if cycle.beneficiaire:
            Notification.objects.create(
                user=cycle.beneficiaire.participant,
                titre='Prise versée',
                message=(
                    f'Vous avez reçu la prise du tour {cycle.numero} de la tontine '
                    f'"{tontine.nom}".'
                ),
                tontine=tontine,
            )

        return Response(CycleSerializer(cycle).data)