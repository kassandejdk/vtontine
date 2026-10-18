"""
Configuration pytest globale et fixtures réutilisables.

Les tests tournent sur SQLite par défaut (cf. RUNNING_TESTS dans settings.py).
Pour les faire tourner sur Postgres : DB_ENGINE=django.db.backends.postgresql pytest
"""
import pytest
from rest_framework.test import APIClient


@pytest.fixture(autouse=True)
def _reset_throttle_cache():
    """Le rate limiting (ScopedRateThrottle) utilise le cache Django, qui
    persiste entre les tests d'un même process pytest. Sans ça, un test
    pourrait être throttled par les appels d'un test précédent."""
    from django.core.cache import cache
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def make_user(db):
    """Fabrique d'utilisateurs (téléphone unique auto-incrémenté)."""
    from django.contrib.auth import get_user_model
    User = get_user_model()
    counter = {'n': 0}

    def _make(**kwargs):
        counter['n'] += 1
        defaults = {
            'nom': f'Nom{counter["n"]}',
            'prenom': f'Prenom{counter["n"]}',
            'telephone': f'7000000{counter["n"]:02d}',
            'genre': 'H',
            'keycloak_id': f'kc-{counter["n"]}',
        }
        defaults.update(kwargs)
        return User.objects.create(**defaults)

    return _make


@pytest.fixture
def user(make_user):
    return make_user()


@pytest.fixture
def auth_client(api_client, user):
    """APIClient authentifié (force_authenticate contourne Keycloak)."""
    api_client.force_authenticate(user=user)
    return api_client


@pytest.fixture
def make_tontine(db, user):
    """Fabrique de tontines, créées par `user` par défaut."""
    from apps.tontines.models import Tontine

    def _make(createur=None, **kwargs):
        defaults = {
            'nom': 'Tontine test',
            'nbre_participant': 5,
            'montant': 5000,
            'type_prise': 'ARGENT',
            'montant_prise': 25000,
            'createur': createur or user,
        }
        defaults.update(kwargs)
        return Tontine.objects.create(**defaults)

    return _make
