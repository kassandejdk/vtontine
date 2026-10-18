"""
Classe d'authentification Django REST Framework pour Keycloak.
Intercepte le header 'Authorization: Bearer <token>' et vérifie
le token auprès de Keycloak.
"""
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from django.contrib.auth import get_user_model
from .keycloak_service import KeycloakService
import logging

logger = logging.getLogger(__name__)
User = get_user_model()


class KeycloakAuthentication(BaseAuthentication):
    """
    Authentification via token Keycloak.
    Usage côté client : Header -> Authorization: Bearer <access_token>
    """

    def authenticate(self, request):
        auth_header = request.headers.get('Authorization', '')

        if not auth_header.startswith('Bearer '):
            return None  # Pas de token → DRF essaiera d'autres méthodes

        access_token = auth_header.split(' ')[1]

        try:
            # 1. Vérifier et décoder le token JWT avec Keycloak
            token_info = KeycloakService.verify_token(access_token)

            # 2. Récupérer l'ID Keycloak (champ "sub" dans le JWT)
            keycloak_id = token_info.get('sub')
            if not keycloak_id:
                raise AuthenticationFailed('Token invalide : sub manquant')

            # 3. Trouver ou créer l'utilisateur Django correspondant
            user = self._get_or_create_user(keycloak_id, token_info)

            return (user, access_token)

        except AuthenticationFailed:
            raise
        except Exception as e:
            logger.error(f"Erreur authentification Keycloak: {e}")
            raise AuthenticationFailed('Token invalide ou expiré')

    def _get_or_create_user(self, keycloak_id, token_info):
        """
        Synchronise l'utilisateur Keycloak avec la base Django.
        Si l'utilisateur n'existe pas encore en base → on le crée.
        """
        try:
            user = User.objects.get(keycloak_id=keycloak_id)
        except User.DoesNotExist:
            # Créer l'utilisateur en base Django depuis les infos du token
            username = token_info.get('preferred_username', '')
            user = User.objects.create(
                keycloak_id=keycloak_id,
                telephone=username,
                nom=token_info.get('family_name', ''),
                prenom=token_info.get('given_name', ''),
                genre=token_info.get('genre', 'H'),
            )
            user.set_unusable_password()  # Pas de mot de passe Django, Keycloak gère ça
            user.save()
        return user