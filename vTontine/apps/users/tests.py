import pytest


@pytest.mark.django_db
class TestMeEndpoint:
    def test_get_me(self, auth_client, user):
        resp = auth_client.get('/api/auth/me/')
        assert resp.status_code == 200
        assert resp.data['telephone'] == user.telephone

    def test_patch_me_met_a_jour_profil(self, auth_client, user, monkeypatch):
        # On mocke la synchro Keycloak (pas de serveur en test)
        from apps.users import views
        monkeypatch.setattr(
            views.KeycloakService, 'update_user_in_keycloak',
            staticmethod(lambda **kwargs: None),
        )
        resp = auth_client.patch('/api/auth/me/', {'prenom': 'Nouveau'}, format='json')
        assert resp.status_code == 200
        user.refresh_from_db()
        assert user.prenom == 'Nouveau'


@pytest.mark.django_db
class TestChangePassword:
    def test_change_password_ok(self, auth_client, user, monkeypatch):
        from apps.users import views
        # mdp actuel valide + set_password réussit
        monkeypatch.setattr(views.KeycloakService, 'login',
                            staticmethod(lambda tel, pwd: {'access_token': 'x'}))
        monkeypatch.setattr(views.KeycloakService, 'set_password',
                            staticmethod(lambda kid, pwd: None))
        resp = auth_client.post('/api/auth/change-password/', {
            'current_password': 'ancien123',
            'new_password': 'nouveau123',
        }, format='json')
        assert resp.status_code == 200

    def test_change_password_actuel_incorrect(self, auth_client, monkeypatch):
        from apps.users import views

        def _fail(tel, pwd):
            raise Exception('bad credentials')

        monkeypatch.setattr(views.KeycloakService, 'login', staticmethod(_fail))
        resp = auth_client.post('/api/auth/change-password/', {
            'current_password': 'faux',
            'new_password': 'nouveau123',
        }, format='json')
        assert resp.status_code == 400

    def test_change_password_trop_court(self, auth_client):
        resp = auth_client.post('/api/auth/change-password/', {
            'current_password': 'ancien123',
            'new_password': 'court',
        }, format='json')
        assert resp.status_code == 400


@pytest.mark.django_db
class TestRechercheUtilisateur:
    def test_recherche_par_telephone_existant(self, auth_client, make_user):
        cible = make_user(telephone='78999888', prenom='Awa', nom='Traoré')
        resp = auth_client.get('/api/auth/users/rechercher/?telephone=78999888')
        assert resp.status_code == 200
        assert resp.data['existe'] is True
        assert resp.data['user']['nom'] == 'Awa Traoré'

    def test_recherche_telephone_inconnu(self, auth_client):
        resp = auth_client.get('/api/auth/users/rechercher/?telephone=00000000')
        assert resp.status_code == 200
        assert resp.data['existe'] is False
