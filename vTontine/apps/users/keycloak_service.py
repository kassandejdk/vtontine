from keycloak import KeycloakOpenID, KeycloakAdmin
from django.conf import settings
import logging

logger = logging.getLogger(__name__)


def get_keycloak_openid():
    return KeycloakOpenID(
        server_url=settings.KEYCLOAK_CONFIG['SERVER_URL'],
        realm_name=settings.KEYCLOAK_CONFIG['REALM'],
        client_id=settings.KEYCLOAK_CONFIG['CLIENT_ID'],
        client_secret_key=settings.KEYCLOAK_CONFIG['CLIENT_SECRET'],
    )


def get_keycloak_admin():
    """Version 7.x de python-keycloak. Identifiants admin lus depuis la config."""
    return KeycloakAdmin(
        server_url=settings.KEYCLOAK_CONFIG['SERVER_URL'],
        username=settings.KEYCLOAK_CONFIG['ADMIN_USER'],
        password=settings.KEYCLOAK_CONFIG['ADMIN_PASSWORD'],
        realm_name=settings.KEYCLOAK_CONFIG['REALM'],
        user_realm_name='master',
        client_id='admin-cli',
        verify=True,
    )


class KeycloakService:

    @staticmethod
    def login(telephone, password):
        keycloak = get_keycloak_openid()
        try:
            token = keycloak.token(telephone, password)
            return token
        except Exception as e:
            logger.error(f"Erreur login Keycloak: {e}")
            raise

    @staticmethod
    def logout(refresh_token):
        keycloak = get_keycloak_openid()
        keycloak.logout(refresh_token)

    @staticmethod
    def verify_token(access_token):
        keycloak = get_keycloak_openid()
        token_info = keycloak.decode_token(access_token)
        return token_info

    

    @staticmethod
    def create_user_in_keycloak(nom, prenom, telephone, password, genre):
        admin = get_keycloak_admin()
        user_data = {
            "username": telephone,
            "firstName": prenom,
            "lastName": nom,
            "attributes": {
                "genre": [genre],
                "telephone": [telephone],
            },
            "credentials": [
                {
                    "type": "password",
                    "value": password,
                    "temporary": False,
                }
            ],
            "enabled": True,
        }
        keycloak_user_id = admin.create_user(user_data)
        return keycloak_user_id

    @staticmethod
    def update_user_in_keycloak(keycloak_id, nom, prenom, genre):
        admin = get_keycloak_admin()
        admin.update_user(
            user_id=keycloak_id,
            payload={
                "firstName": prenom,
                "lastName": nom,
                "attributes": {"genre": [genre]},
            },
        )

    @staticmethod
    def set_user_enabled(keycloak_id, enabled):
        """Active (True) ou suspend (False) le compte Keycloak."""
        if not keycloak_id:
            return
        admin = get_keycloak_admin()
        admin.update_user(user_id=keycloak_id, payload={'enabled': bool(enabled)})

    @staticmethod
    def set_password(keycloak_id, password):
        """Définit un nouveau mot de passe (non temporaire) pour l'utilisateur."""
        admin = get_keycloak_admin()
        admin.set_user_password(
            user_id=keycloak_id, password=password, temporary=False
        )

    @staticmethod
    def refresh_token(refresh_token):
        keycloak = get_keycloak_openid()
        return keycloak.refresh_token(refresh_token)

    @staticmethod
    def get_user_info(access_token):
        keycloak = get_keycloak_openid()
        return keycloak.userinfo(access_token)