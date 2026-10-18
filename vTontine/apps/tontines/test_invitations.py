import pytest

from apps.tontines.models import InvitationTontine, InvitationLien, Participation
from apps.notifications.models import Notification


@pytest.mark.django_db
class TestInvitationParTelephone:
    def test_inviter_cree_invitation_et_notification(self, auth_client, make_tontine, make_user):
        tontine = make_tontine()
        invite = make_user(telephone='75123456')
        resp = auth_client.post(
            f'/api/tontines/{tontine.id}/invitations/telephone/',
            {'telephone': '75123456'}, format='json',
        )
        assert resp.status_code == 200
        assert InvitationTontine.objects.filter(tontine=tontine, invite=invite).exists()
        assert Notification.objects.filter(user=invite, invitation_token__isnull=False).exists()

    def test_inviter_numero_inconnu_404(self, auth_client, make_tontine):
        tontine = make_tontine()
        resp = auth_client.post(
            f'/api/tontines/{tontine.id}/invitations/telephone/',
            {'telephone': '00000000'}, format='json',
        )
        assert resp.status_code == 404


@pytest.mark.django_db
class TestRejoindreEtRefuser:
    def _inviter(self, tontine, invite_par, invite):
        return InvitationTontine.objects.create(
            tontine=tontine, invite_par=invite_par, invite=invite, type='DIRECTE'
        )

    def test_rejoindre_via_token(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user)
        invite = make_user(telephone='76000001')
        invitation = self._inviter(tontine, user, invite)

        api_client.force_authenticate(user=invite)
        resp = api_client.post(
            f'/api/tontines/rejoindre/{invitation.token}/',
            {'regles_acceptees': []}, format='json',
        )
        assert resp.status_code == 201
        invitation.refresh_from_db()
        assert invitation.statut == 'ACCEPTEE'
        assert Participation.objects.filter(
            tontine=tontine, participant=invite, statut='CONFIRME'
        ).exists()

    def test_refuser_invitation(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user)
        invite = make_user(telephone='76000002')
        invitation = self._inviter(tontine, user, invite)

        api_client.force_authenticate(user=invite)
        resp = api_client.post(f'/api/tontines/rejoindre/{invitation.token}/refuser/')
        assert resp.status_code == 200
        invitation.refresh_from_db()
        assert invitation.statut == 'REFUSEE'


@pytest.mark.django_db
class TestLienPartage:
    def test_createur_genere_lien(self, auth_client, make_tontine, user):
        tontine = make_tontine(createur=user)
        resp = auth_client.post(f'/api/tontines/{tontine.id}/invitations/lien/')
        assert resp.status_code == 200
        assert 'lien_web' in resp.data
        assert resp.data['token'] in resp.data['lien_web']
        assert InvitationLien.objects.filter(tontine=tontine, est_actif=True).count() == 1

    def test_non_createur_ne_peut_pas_generer(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user)
        autre = make_user()
        api_client.force_authenticate(user=autre)
        resp = api_client.post(f'/api/tontines/{tontine.id}/invitations/lien/')
        assert resp.status_code == 403

    def test_nouveau_lien_desactive_lancien(self, auth_client, make_tontine, user):
        tontine = make_tontine(createur=user)
        auth_client.post(f'/api/tontines/{tontine.id}/invitations/lien/')
        auth_client.post(f'/api/tontines/{tontine.id}/invitations/lien/')
        assert InvitationLien.objects.filter(tontine=tontine, est_actif=True).count() == 1
        assert InvitationLien.objects.filter(tontine=tontine).count() == 2

    def test_rejoindre_via_lien_generique(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user)
        lien = InvitationLien.objects.create(tontine=tontine, cree_par=user)
        nouveau = make_user()
        api_client.force_authenticate(user=nouveau)
        resp = api_client.post(
            f'/api/tontines/rejoindre/{lien.token}/',
            {'regles_acceptees': []}, format='json',
        )
        assert resp.status_code == 201
        assert Participation.objects.filter(
            tontine=tontine, participant=nouveau, statut='CONFIRME'
        ).exists()

    def test_infos_invitation_par_token(self, api_client, make_tontine, make_user, user):
        """GET deep link : prévisualiser la tontine ciblée par un token."""
        tontine = make_tontine(createur=user, nom='Tontine du lien')
        lien = InvitationLien.objects.create(tontine=tontine, cree_par=user)
        nouveau = make_user()
        api_client.force_authenticate(user=nouveau)
        resp = api_client.get(f'/api/tontines/rejoindre/{lien.token}/')
        assert resp.status_code == 200
        assert resp.data['id'] == tontine.id
        assert resp.data['nom'] == 'Tontine du lien'

    def test_infos_invitation_token_invalide(self, auth_client):
        import uuid
        resp = auth_client.get(f'/api/tontines/rejoindre/{uuid.uuid4()}/')
        assert resp.status_code == 404


@pytest.mark.django_db
class TestDemandeAdhesionNotif:
    def test_demande_notifie_le_createur(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user, visibilite=True, statut='INCOMPLET')
        demandeur = make_user()
        api_client.force_authenticate(user=demandeur)
        resp = api_client.post(
            f'/api/tontines/{tontine.id}/demandes/',
            {'regles_acceptees': []}, format='json',
        )
        assert resp.status_code == 201
        assert Notification.objects.filter(
            user=user, titre="Nouvelle demande d'adhésion"
        ).exists()

    def test_decouvrir_masque_tontine_deja_demandee(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user, visibilite=True, statut='INCOMPLET')
        demandeur = make_user()
        api_client.force_authenticate(user=demandeur)
        # avant : la tontine apparaît dans découvrir
        assert any(t['id'] == tontine.id for t in api_client.get('/api/tontines/decouvrir/').data)
        # on soumet une demande
        api_client.post(f'/api/tontines/{tontine.id}/demandes/', {'regles_acceptees': []}, format='json')
        # après : elle disparaît du découvrir
        assert not any(t['id'] == tontine.id for t in api_client.get('/api/tontines/decouvrir/').data)


@pytest.mark.django_db
class TestInvitationsRecues:
    def test_liste_invitations_recues(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user)
        invite = make_user(telephone='76000003')
        InvitationTontine.objects.create(
            tontine=tontine, invite_par=user, invite=invite, type='DIRECTE'
        )
        api_client.force_authenticate(user=invite)
        resp = api_client.get('/api/tontines/invitations/')
        assert resp.status_code == 200
        assert len(resp.data) == 1
        assert resp.data[0]['tontine']['id'] == tontine.id

    def test_filtre_par_statut(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user)
        invite = make_user(telephone='76000004')
        InvitationTontine.objects.create(
            tontine=tontine, invite_par=user, invite=invite,
            type='DIRECTE', statut='REFUSEE',
        )
        api_client.force_authenticate(user=invite)
        resp = api_client.get('/api/tontines/invitations/?statut=EN_ATTENTE')
        assert resp.status_code == 200
        assert len(resp.data) == 0
