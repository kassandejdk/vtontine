import pytest

from apps.tontines.models import Participation
from apps.paiements.models import Paiement
from apps.notifications.models import Notification


@pytest.fixture
def tontine_avec_membre(make_tontine, make_user):
    """Tontine + un membre confirmé (différent du créateur)."""
    tontine = make_tontine()
    membre = make_user()
    participation = Participation.objects.create(
        tontine=tontine, participant=membre, statut='CONFIRME', ordre_prise=1
    )
    return tontine, membre, participation


@pytest.mark.django_db
class TestEnregistrementPaiement:
    def test_membre_enregistre_paiement(self, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        api_client.force_authenticate(user=membre)
        resp = api_client.post('/api/paiements/', {
            'participation': participation.id,
            'montant': 5000,
        }, format='json')
        assert resp.status_code == 201
        assert resp.data['est_confirmer'] is False
        assert resp.data['transaction_id']  # généré automatiquement
        assert Paiement.objects.filter(participation=participation).count() == 1

    def test_paiement_notifie_le_createur(self, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        api_client.force_authenticate(user=membre)
        api_client.post('/api/paiements/', {
            'participation': participation.id, 'montant': 5000,
        }, format='json')
        assert Notification.objects.filter(
            user=tontine.createur, titre='Nouveau paiement à confirmer'
        ).exists()

    def test_ne_peut_pas_payer_pour_autrui(self, api_client, tontine_avec_membre, make_user):
        tontine, membre, participation = tontine_avec_membre
        intrus = make_user()
        api_client.force_authenticate(user=intrus)
        resp = api_client.post('/api/paiements/', {
            'participation': participation.id, 'montant': 5000,
        }, format='json')
        assert resp.status_code == 400

    def test_montant_doit_etre_positif(self, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        api_client.force_authenticate(user=membre)
        resp = api_client.post('/api/paiements/', {
            'participation': participation.id, 'montant': 0,
        }, format='json')
        assert resp.status_code == 400


@pytest.mark.django_db
class TestConfirmationPaiement:
    def _creer_paiement(self, participation):
        return Paiement.objects.create(
            participation=participation, montant=5000, transaction_id='TXN-TEST-1'
        )

    def test_createur_confirme(self, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        paiement = self._creer_paiement(participation)
        api_client.force_authenticate(user=tontine.createur)
        resp = api_client.patch(f'/api/paiements/{paiement.id}/confirmer/')
        assert resp.status_code == 200
        paiement.refresh_from_db()
        assert paiement.est_confirmer is True
        assert Notification.objects.filter(
            user=membre, titre='Paiement confirmé'
        ).exists()

    def test_non_createur_ne_peut_pas_confirmer(self, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        paiement = self._creer_paiement(participation)
        api_client.force_authenticate(user=membre)
        resp = api_client.patch(f'/api/paiements/{paiement.id}/confirmer/')
        assert resp.status_code == 403

    def test_double_confirmation_refusee(self, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        paiement = self._creer_paiement(participation)
        paiement.statut = 'CONFIRME'
        paiement.est_confirmer = True
        paiement.save()
        api_client.force_authenticate(user=tontine.createur)
        resp = api_client.patch(f'/api/paiements/{paiement.id}/confirmer/')
        assert resp.status_code == 400


@pytest.mark.django_db
class TestRefusPaiement:
    def _creer_paiement(self, participation):
        return Paiement.objects.create(
            participation=participation, montant=5000, transaction_id='TXN-REF-1'
        )

    def test_createur_refuse(self, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        paiement = self._creer_paiement(participation)
        api_client.force_authenticate(user=tontine.createur)
        resp = api_client.patch(f'/api/paiements/{paiement.id}/refuser/', {'motif': 'non reçu'}, format='json')
        assert resp.status_code == 200
        paiement.refresh_from_db()
        assert paiement.statut == 'REFUSE'
        assert paiement.est_confirmer is False
        assert Notification.objects.filter(user=membre, titre='Paiement refusé').exists()

    def test_non_createur_ne_peut_pas_refuser(self, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        paiement = self._creer_paiement(participation)
        api_client.force_authenticate(user=membre)
        resp = api_client.patch(f'/api/paiements/{paiement.id}/refuser/')
        assert resp.status_code == 403

    def test_double_refus_refuse(self, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        paiement = self._creer_paiement(participation)
        paiement.statut = 'REFUSE'
        paiement.save()
        api_client.force_authenticate(user=tontine.createur)
        resp = api_client.patch(f'/api/paiements/{paiement.id}/refuser/')
        assert resp.status_code == 400


@pytest.mark.django_db
class TestListePaiements:
    def test_membre_voit_ses_paiements(self, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        Paiement.objects.create(
            participation=participation, montant=5000, transaction_id='TXN-A'
        )
        api_client.force_authenticate(user=membre)
        resp = api_client.get('/api/paiements/')
        assert resp.status_code == 200
        assert len(resp.data) == 1

    def test_createur_voit_tous_les_paiements_de_sa_tontine(self, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        Paiement.objects.create(
            participation=participation, montant=5000, transaction_id='TXN-B'
        )
        api_client.force_authenticate(user=tontine.createur)
        resp = api_client.get(f'/api/paiements/?tontine={tontine.id}')
        assert resp.status_code == 200
        assert len(resp.data) == 1

    def test_membre_voit_le_fil_complet_de_la_tontine(self, api_client, tontine_avec_membre, make_user):
        """#4 : un membre confirmé voit tous les paiements de la tontine (transparence)."""
        tontine, membre, participation = tontine_avec_membre
        # un autre membre confirmé + son paiement
        autre = make_user()
        from apps.tontines.models import Participation
        p2 = Participation.objects.create(tontine=tontine, participant=autre, statut='CONFIRME', ordre_prise=2)
        Paiement.objects.create(participation=participation, montant=5000, transaction_id='TXN-C')
        Paiement.objects.create(participation=p2, montant=5000, transaction_id='TXN-D')
        # le premier membre voit les DEUX paiements
        api_client.force_authenticate(user=membre)
        resp = api_client.get(f'/api/paiements/?tontine={tontine.id}')
        assert resp.status_code == 200
        assert len(resp.data) == 2
