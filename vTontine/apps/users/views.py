from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework.parsers import MultiPartParser, FormParser
from django.contrib.auth import get_user_model, authenticate
from django.db.models import Q, Sum
from .keycloak_service import KeycloakService

from .serializers import (
    UserSerializer, RegisterSerializer, UserUpdateSerializer, AdminUserSerializer,
)
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError

User = get_user_model()


class RegisterView(APIView):
    """
    POST /api/auth/register/
    Inscrit un utilisateur dans Keycloak ET dans Django.
    """
    permission_classes = [AllowAny]
    throttle_scope = 'auth_register'

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        user = User.objects.create_user(
            # username=data['telephone'],       # ou telephone si USERNAME_FIELD
            telephone=data['telephone'],
            nom=data['nom'],
            prenom=data['prenom'],
            genre=data['genre'],
            password=data['password'],
        )

        refresh = RefreshToken.for_user(user)
        return Response({
            'message': 'Compte créé avec succès',
            'user': UserSerializer(user, context={'request': request}).data,
            'access_token': str(refresh.access_token),
            'refresh_token': str(refresh),
        }, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    """POST /api/auth/login/ — { telephone, password }"""
    permission_classes = [AllowAny]
    throttle_scope = 'auth_login'

    def post(self, request):
        telephone = request.data.get('telephone')
        password = request.data.get('password')
        if not telephone or not password:
            return Response(
                {'error': 'Téléphone et mot de passe requis'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # authenticate() utilise USERNAME_FIELD (telephone)
        user = authenticate(request, username=telephone, password=password)
        if user is None:
            return Response(
                {'error': 'Identifiants incorrects'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        refresh = RefreshToken.for_user(user)
        return Response({
            'access_token': str(refresh.access_token),
            'refresh_token': str(refresh),
            'expires_in': int(refresh.access_token.lifetime.total_seconds()),
        })


class LogoutView(APIView):
    """POST /api/auth/logout/ — blackliste le refresh token"""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        refresh_token = request.data.get('refresh_token')
        if not refresh_token:
            return Response({'error': 'refresh_token requis'}, status=400)
        try:
            RefreshToken(refresh_token).blacklist()
            return Response({'message': 'Déconnecté avec succès'})
        except TokenError as e:
            return Response({'error': str(e)}, status=400)
        
        
class RefreshTokenView(APIView):
    """POST /api/auth/refresh/ — { refresh_token }"""
    permission_classes = [AllowAny]
    throttle_scope = 'auth_refresh'

    def post(self, request):
        refresh_token = request.data.get('refresh_token')
        if not refresh_token:
            return Response({'error': 'refresh_token requis'}, status=400)
        try:
            refresh = RefreshToken(refresh_token)
            return Response({
                'access_token': str(refresh.access_token),
                'expires_in': int(refresh.access_token.lifetime.total_seconds()),
            })
        except TokenError:
            return Response(
                {'error': 'Token expiré, reconnectez-vous'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            UserSerializer(request.user, context={'request': request}).data
        )

    def patch(self, request):
        serializer = UserUpdateSerializer(
            request.user, data=request.data, partial=True
        )
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(
            UserSerializer(user, context={'request': request}).data
        )
        
        
class MePhotoView(APIView):
    """
    POST /api/auth/me/photo/  (multipart, champ 'photo')
    Met à jour la photo de profil de l'utilisateur connecté.
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        photo = request.FILES.get('photo')
        if not photo:
            return Response(
                {'error': "Aucun fichier 'photo' fourni."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        request.user.photo = photo
        request.user.save(update_fields=['photo'])
        return Response(
            UserSerializer(request.user, context={'request': request}).data
        )


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_scope = 'auth_change_password'

    def post(self, request):
        current = request.data.get('current_password') or ''
        new = request.data.get('new_password') or ''

        if not current or not new:
            return Response(
                {'error': 'Le mot de passe actuel et le nouveau sont requis.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(new) < 8:
            return Response(
                {'error': 'Le nouveau mot de passe doit faire au moins 8 caractères.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not request.user.check_password(current):
            return Response(
                {'error': 'Mot de passe actuel incorrect.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        request.user.set_password(new)
        request.user.save(update_fields=['password'])
        return Response({'message': 'Mot de passe modifié avec succès.'})

class RechercherUserParTelephoneView(APIView):
    """
    GET /api/auth/users/rechercher/?telephone=XXXXXXXX
    → Recherche globale d'un utilisateur par son numéro de téléphone.
    (La recherche contextualisée à une tontine est dans apps.tontines.)
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
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


# ─── Espace administrateur plateforme (is_staff) ─────────────────────────────

class AdminStatsView(APIView):
    """GET /api/auth/admin/stats/ — indicateurs plateforme (admin uniquement)."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        from apps.tontines.models import Tontine
        from apps.paiements.models import Paiement
        return Response({
            'nb_utilisateurs': User.objects.count(),
            'nb_tontines': Tontine.objects.count(),
            'tontines_par_statut': {
                'INCOMPLET': Tontine.objects.filter(statut='INCOMPLET').count(),
                'COMPLET': Tontine.objects.filter(statut='COMPLET').count(),
                'TERMINE': Tontine.objects.filter(statut='TERMINE').count(),
            },
            'total_collecte': Paiement.objects.filter(statut='CONFIRME')
            .aggregate(s=Sum('montant'))['s'] or 0,
            'paiements_en_attente': Paiement.objects.filter(statut='EN_ATTENTE').count(),
        })


class AdminTontinesView(APIView):
    """GET /api/auth/admin/tontines/?q= — toutes les tontines (admin uniquement)."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        from apps.tontines.models import Tontine
        from apps.tontines.serializers import TontineSerializer
        qs = Tontine.objects.select_related('createur').order_by('-date_creation')
        q = (request.query_params.get('q') or '').strip()
        if q:
            qs = qs.filter(Q(nom__icontains=q) | Q(createur__telephone__icontains=q))
        return Response(
            TontineSerializer(qs, many=True, context={'request': request}).data
        )


class AdminUsersView(APIView):
    """GET /api/auth/admin/users/?q= — tous les utilisateurs (admin uniquement)."""
    permission_classes = [IsAdminUser]

    def get(self, request):
        qs = User.objects.order_by('-date_creation')
        q = (request.query_params.get('q') or '').strip()
        if q:
            qs = qs.filter(
                Q(nom__icontains=q) | Q(prenom__icontains=q) | Q(telephone__icontains=q)
            )
        return Response(
            AdminUserSerializer(qs, many=True, context={'request': request}).data
        )