from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404

from apps.tontines.models import Tontine, Participation
from apps.notifications.models import Notification
from .models import Paiement
from .serializers import PaiementSerializer, PaiementCreateSerializer
from .verification_ia import verifier_paiement


class PaiementListCreateView(APIView):
    """
    GET  /api/paiements/                 → paiements de l'utilisateur connecté.
         /api/paiements/?tontine=<id>    → si l'user est créateur de la tontine,
                                            tous les paiements de celle-ci
                                            (sinon, seulement les siens).
    POST /api/paiements/                 → enregistrer un paiement.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Paiement.objects.select_related(
            'participation',
            'participation__participant',
            'participation__tontine',
        )

        tontine_id = request.query_params.get('tontine')
        if tontine_id:
            tontine = get_object_or_404(Tontine, id=tontine_id)
            est_membre = Participation.objects.filter(
                tontine=tontine, participant=request.user, statut='CONFIRME'
            ).exists()
            # Créateur ET membres confirmés voient tout le fil des paiements
            # de la tontine (transparence type « groupe »).
            if tontine.createur_id == request.user.id or est_membre:
                qs = qs.filter(participation__tontine_id=tontine_id)
            else:
                qs = qs.filter(
                    participation__tontine_id=tontine_id,
                    participation__participant=request.user,
                )
        else:
            qs = qs.filter(participation__participant=request.user)

        return Response(
            PaiementSerializer(qs, many=True, context={'request': request}).data
        )

    def post(self, request):
        serializer = PaiementCreateSerializer(
            data=request.data, context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        paiement = serializer.save()

        # Vérification automatique (IA) de la pièce jointe, si fournie.
        # Purement indicative : n'empêche jamais l'enregistrement du paiement.
        if paiement.piece_jointe:
            tontine_ref = paiement.participation.tontine
            statut_ia, details_ia = verifier_paiement(
                montant_attendu=tontine_ref.montant,
                numero_attendu=tontine_ref.createur.telephone,
                image_file=paiement.piece_jointe,
            )
            paiement.verification_ia_statut = statut_ia
            paiement.verification_ia_details = details_ia
            paiement.save(update_fields=['verification_ia_statut', 'verification_ia_details'])

        # Notifier le créateur qu'un paiement attend sa confirmation
        tontine = paiement.participation.tontine
        if tontine.createur_id != request.user.id:
            Notification.objects.create(
                user=tontine.createur,
                titre='Nouveau paiement à confirmer',
                message=(
                    f'{request.user.prenom} {request.user.nom} a enregistré un paiement '
                    f'de {paiement.montant} FCFA pour la tontine "{tontine.nom}".'
                ),
                tontine=tontine,
            )

        return Response(
            PaiementSerializer(paiement, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )


class PaiementDetailView(APIView):
    """GET /api/paiements/<id>/ — détail (payeur ou créateur de la tontine)."""
    permission_classes = [IsAuthenticated]

    def get(self, request, paiement_id):
        paiement = get_object_or_404(
            Paiement.objects.select_related(
                'participation',
                'participation__participant',
                'participation__tontine',
            ),
            id=paiement_id,
        )
        participation = paiement.participation
        est_payeur = participation.participant_id == request.user.id
        est_createur = participation.tontine.createur_id == request.user.id
        if not (est_payeur or est_createur):
            return Response(
                {'error': "Vous n'avez pas accès à ce paiement."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return Response(PaiementSerializer(paiement, context={'request': request}).data)


class PaiementConfirmerView(APIView):
    """
    PATCH /api/paiements/<id>/confirmer/
    Réservé au créateur de la tontine : atteste la réception du paiement.
    """
    permission_classes = [IsAuthenticated]

    def patch(self, request, paiement_id):
        paiement = get_object_or_404(
            Paiement.objects.select_related(
                'participation',
                'participation__participant',
                'participation__tontine',
            ),
            id=paiement_id,
        )
        tontine = paiement.participation.tontine

        if tontine.createur_id != request.user.id:
            return Response(
                {'error': 'Seul le créateur de la tontine peut confirmer un paiement.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        if paiement.statut == 'CONFIRME':
            return Response(
                {'error': 'Ce paiement est déjà confirmé.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        paiement.statut = 'CONFIRME'
        paiement.est_confirmer = True
        paiement.save(update_fields=['statut', 'est_confirmer'])

        Notification.objects.create(
            user=paiement.participation.participant,
            titre='Paiement confirmé',
            message=(
                f'Votre paiement de {paiement.montant} FCFA pour la tontine '
                f'"{tontine.nom}" a été confirmé.'
            ),
            tontine=tontine,
        )

        return Response(PaiementSerializer(paiement, context={'request': request}).data)


class PaiementRefuserView(APIView):
    """
    PATCH /api/paiements/<id>/refuser/
    Réservé au créateur : rejette un paiement (non reçu / montant erroné...).
    """
    permission_classes = [IsAuthenticated]

    def patch(self, request, paiement_id):
        paiement = get_object_or_404(
            Paiement.objects.select_related(
                'participation',
                'participation__participant',
                'participation__tontine',
            ),
            id=paiement_id,
        )
        tontine = paiement.participation.tontine

        if tontine.createur_id != request.user.id:
            return Response(
                {'error': 'Seul le créateur de la tontine peut refuser un paiement.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        if paiement.statut == 'REFUSE':
            return Response(
                {'error': 'Ce paiement est déjà refusé.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        motif = (request.data.get('motif') or '').strip()
        paiement.statut = 'REFUSE'
        paiement.est_confirmer = False
        paiement.save(update_fields=['statut', 'est_confirmer'])

        message = (
            f'Votre paiement de {paiement.montant} FCFA pour la tontine '
            f'"{tontine.nom}" a été refusé.'
        )
        if motif:
            message += f' Motif : {motif}'
        Notification.objects.create(
            user=paiement.participation.participant,
            titre='Paiement refusé',
            message=message,
            tontine=tontine,
        )

        return Response(PaiementSerializer(paiement, context={'request': request}).data)
