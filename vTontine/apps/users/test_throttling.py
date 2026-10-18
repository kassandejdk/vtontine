"""
Tests du rate limiting sur les endpoints d'authentification sensibles.

Note : DRF fige `SimpleRateThrottle.THROTTLE_RATES` en attribut de classe dès
le premier import de `rest_framework.throttling` (généralement au chargement
des apps Django, avant toute exécution de test). Un override de
`settings.REST_FRAMEWORK['DEFAULT_THROTTLE_RATES']` en cours de test suite
n'a donc aucun effet fiable. On teste ici directement contre les taux réels
configurés dans `settings.py`, lus dynamiquement — pas contre des taux
artificiellement abaissés.
"""
import pytest
from django.conf import settings


def _limite(scope):
    rate = settings.REST_FRAMEWORK['DEFAULT_THROTTLE_RATES'][scope]
    nombre, _periode = rate.split('/')
    return int(nombre)


@pytest.mark.django_db
class TestThrottlingLogin:
    def test_bloque_apres_la_limite(self, api_client, monkeypatch):
        from apps.users import views
        monkeypatch.setattr(
            views.KeycloakService, 'login',
            staticmethod(lambda tel, pwd: (_ for _ in ()).throw(Exception('bad'))),
        )
        limite = _limite('auth_login')
        for _ in range(limite):
            resp = api_client.post('/api/auth/login/', {
                'telephone': '70000000', 'password': 'x',
            }, format='json')
            assert resp.status_code == 401
        # une requête de plus que la limite → throttled
        resp = api_client.post('/api/auth/login/', {
            'telephone': '70000000', 'password': 'x',
        }, format='json')
        assert resp.status_code == 429

    def test_scopes_independants(self, api_client, monkeypatch):
        """Épuiser le quota login n'affecte pas le quota register."""
        from apps.users import views
        monkeypatch.setattr(
            views.KeycloakService, 'login',
            staticmethod(lambda tel, pwd: (_ for _ in ()).throw(Exception('bad'))),
        )
        for _ in range(_limite('auth_login') + 1):
            resp = api_client.post('/api/auth/login/', {
                'telephone': '70000000', 'password': 'x',
            }, format='json')
        assert resp.status_code == 429  # le quota login est bien épuisé

        # register a son propre quota, distinct de celui de login
        resp = api_client.post('/api/auth/register/', {
            'nom': 'A', 'prenom': 'B', 'telephone': '70000001',
            'password': 'motdepasse123', 'genre': 'H',
        }, format='json')
        assert resp.status_code != 429


@pytest.mark.django_db
class TestThrottlingChangePassword:
    def test_bloque_apres_la_limite(self, auth_client, monkeypatch):
        from apps.users import views

        def _fail(tel, pwd):
            raise Exception('bad credentials')

        monkeypatch.setattr(views.KeycloakService, 'login', staticmethod(_fail))
        limite = _limite('auth_change_password')
        for _ in range(limite):
            resp = auth_client.post('/api/auth/change-password/', {
                'current_password': 'faux', 'new_password': 'nouveau123',
            }, format='json')
            assert resp.status_code == 400
        resp = auth_client.post('/api/auth/change-password/', {
            'current_password': 'faux', 'new_password': 'nouveau123',
        }, format='json')
        assert resp.status_code == 429
