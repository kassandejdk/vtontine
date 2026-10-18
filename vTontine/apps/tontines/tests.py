import pytest

from apps.tontines.models import Tontine, Participation, RegleTontine, MessageTontine


@pytest.mark.django_db
class TestMethodesPaiement:
    def test_createur_ajoute_methode(self, auth_client, make_tontine, user):
        tontine = make_tontine(createur=user)
        resp = auth_client.post(
            f'/api/tontines/{tontine.id}/methodes-paiement/',
            {'libelle': 'Orange Money', 'code_ussd': '*144*10*70000000*{montant}#'},
            format='json',
        )
        assert resp.status_code == 201
        # apparaît dans le détail de la tontine
        detail = auth_client.get(f'/api/tontines/{tontine.id}/')
        assert len(detail.data['methodes_paiement']) == 1
        assert detail.data['methodes_paiement'][0]['libelle'] == 'Orange Money'

    def test_non_createur_refuse(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user)
        autre = make_user()
        api_client.force_authenticate(user=autre)
        resp = api_client.post(
            f'/api/tontines/{tontine.id}/methodes-paiement/',
            {'libelle': 'X', 'code_ussd': '*1#'}, format='json',
        )
        assert resp.status_code == 403

    def test_supprimer_methode(self, auth_client, make_tontine, user):
        from apps.tontines.models import MethodePaiement
        tontine = make_tontine(createur=user)
        m = MethodePaiement.objects.create(tontine=tontine, libelle='Moov', code_ussd='*555#')
        resp = auth_client.delete(f'/api/tontines/{tontine.id}/methodes-paiement/{m.id}/')
        assert resp.status_code == 204
        assert not MethodePaiement.objects.filter(id=m.id).exists()


@pytest.mark.django_db
class TestChatTontine:
    def test_membre_envoie_et_lit(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user)
        membre = make_user()
        Participation.objects.create(tontine=tontine, participant=membre, statut='CONFIRME')
        api_client.force_authenticate(user=membre)
        # envoyer
        resp = api_client.post(
            f'/api/tontines/{tontine.id}/messages/',
            {'contenu': 'Bonjour à tous'}, format='json',
        )
        assert resp.status_code == 201
        # lire
        resp = api_client.get(f'/api/tontines/{tontine.id}/messages/')
        assert resp.status_code == 200
        assert len(resp.data) == 1
        assert resp.data[0]['contenu'] == 'Bonjour à tous'

    def test_non_membre_refuse(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user)
        etranger = make_user()
        api_client.force_authenticate(user=etranger)
        resp = api_client.get(f'/api/tontines/{tontine.id}/messages/')
        assert resp.status_code == 403

    def test_polling_after(self, api_client, make_tontine, user):
        tontine = make_tontine(createur=user)
        api_client.force_authenticate(user=user)
        m1 = MessageTontine.objects.create(tontine=tontine, auteur=user, contenu='un')
        MessageTontine.objects.create(tontine=tontine, auteur=user, contenu='deux')
        resp = api_client.get(f'/api/tontines/{tontine.id}/messages/?after={m1.id}')
        assert resp.status_code == 200
        assert len(resp.data) == 1
        assert resp.data[0]['contenu'] == 'deux'

    def test_envoi_message_media(self, api_client, make_tontine, user):
        from django.core.files.uploadedfile import SimpleUploadedFile
        tontine = make_tontine(createur=user)
        api_client.force_authenticate(user=user)
        fichier = SimpleUploadedFile('photo.jpg', b'\xff\xd8\xff\xe0fakejpeg', content_type='image/jpeg')
        resp = api_client.post(
            f'/api/tontines/{tontine.id}/messages/',
            {'type': 'IMAGE', 'piece_jointe': fichier}, format='multipart',
        )
        assert resp.status_code == 201
        assert resp.data['type'] == 'IMAGE'
        assert resp.data['piece_jointe'] is not None

    def test_message_vide_refuse(self, api_client, make_tontine, user):
        tontine = make_tontine(createur=user)
        api_client.force_authenticate(user=user)
        resp = api_client.post(
            f'/api/tontines/{tontine.id}/messages/', {'contenu': ''}, format='json')
        assert resp.status_code == 400


@pytest.mark.django_db
class TestCreationTontine:
    def test_creation_simple(self, auth_client):
        resp = auth_client.post('/api/tontines/', {
            'nom': 'Wend kunni',
            'nbre_participant': 6,
            'montant': 5000,
            'type_prise': 'ARGENT',
            'montant_prise': 30000,
        }, format='json')
        assert resp.status_code == 201
        assert resp.data['nom'] == 'Wend kunni'
        assert resp.data['statut'] == 'INCOMPLET'

    def test_creation_createur_membre_ne_plante_pas(self, auth_client, user):
        """Régression : createur_est_membre=True déclenchait un IntegrityError
        (double création de Participation)."""
        resp = auth_client.post('/api/tontines/', {
            'nom': 'Avec créateur membre',
            'nbre_participant': 4,
            'montant': 2000,
            'type_prise': 'ARGENT',
            'montant_prise': 8000,
            'createur_est_membre': True,
        }, format='json')
        assert resp.status_code == 201

        tontine = Tontine.objects.get(id=resp.data['id'])
        participations = Participation.objects.filter(tontine=tontine, participant=user)
        assert participations.count() == 1
        p = participations.first()
        assert p.statut == 'CONFIRME'
        assert p.est_createur is True

    def test_montant_prise_requis_pour_argent(self, auth_client):
        resp = auth_client.post('/api/tontines/', {
            'nom': 'Sans montant prise',
            'nbre_participant': 4,
            'montant': 2000,
            'type_prise': 'ARGENT',
        }, format='json')
        assert resp.status_code == 400
        assert 'montant_prise' in resp.data

    def test_nbre_participant_minimum(self, auth_client):
        resp = auth_client.post('/api/tontines/', {
            'nom': 'Trop petite',
            'nbre_participant': 1,
            'montant': 2000,
            'type_prise': 'ARGENT',
            'montant_prise': 2000,
        }, format='json')
        assert resp.status_code == 400


@pytest.mark.django_db
class TestSuppressionTontine:
    def test_delete_incomplet_ok(self, auth_client, make_tontine):
        tontine = make_tontine(statut='INCOMPLET')
        resp = auth_client.delete(f'/api/tontines/{tontine.id}/')
        assert resp.status_code == 204
        assert not Tontine.objects.filter(id=tontine.id).exists()

    def test_delete_complet_refuse(self, auth_client, make_tontine):
        tontine = make_tontine(statut='COMPLET')
        resp = auth_client.delete(f'/api/tontines/{tontine.id}/')
        assert resp.status_code == 400
        assert Tontine.objects.filter(id=tontine.id).exists()

    def test_delete_non_createur_interdit(self, api_client, make_tontine, make_user):
        tontine = make_tontine()
        autre = make_user()
        api_client.force_authenticate(user=autre)
        resp = api_client.delete(f'/api/tontines/{tontine.id}/')
        assert resp.status_code == 403


@pytest.mark.django_db
class TestQuitterTontine:
    def test_membre_quitte(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user, statut='INCOMPLET')
        membre = make_user()
        Participation.objects.create(tontine=tontine, participant=membre, statut='CONFIRME')
        api_client.force_authenticate(user=membre)
        resp = api_client.delete(f'/api/tontines/{tontine.id}/quitter/')
        assert resp.status_code == 204
        assert not Participation.objects.filter(tontine=tontine, participant=membre).exists()

    def test_createur_ne_peut_pas_quitter(self, auth_client, make_tontine, user):
        tontine = make_tontine(createur=user, createur_est_membre=True)
        resp = auth_client.delete(f'/api/tontines/{tontine.id}/quitter/')
        assert resp.status_code == 400

    def test_non_membre_ne_peut_pas_quitter(self, api_client, make_tontine, make_user, user):
        tontine = make_tontine(createur=user, statut='INCOMPLET')
        etranger = make_user()
        api_client.force_authenticate(user=etranger)
        resp = api_client.delete(f'/api/tontines/{tontine.id}/quitter/')
        assert resp.status_code == 400


@pytest.mark.django_db
class TestReglesCRUD:
    def test_createur_ajoute_regle(self, auth_client, make_tontine):
        tontine = make_tontine()
        resp = auth_client.post(f'/api/tontines/{tontine.id}/regles/', {
            'titre': 'Être ponctuel',
            'description': 'Payer avant le 5 du mois',
            'categorie': 'COMPORTEMENT',
            'est_obligatoire': True,
        }, format='json')
        assert resp.status_code == 201
        assert RegleTontine.objects.filter(tontine=tontine).count() == 1

    def test_non_createur_ne_peut_pas_ajouter(self, api_client, make_tontine, make_user):
        tontine = make_tontine()
        autre = make_user()
        api_client.force_authenticate(user=autre)
        resp = api_client.post(f'/api/tontines/{tontine.id}/regles/', {
            'titre': 'X', 'description': 'Y',
        }, format='json')
        assert resp.status_code == 403

    def test_modifier_et_supprimer_regle(self, auth_client, make_tontine):
        tontine = make_tontine()
        regle = RegleTontine.objects.create(
            tontine=tontine, titre='Ancien', description='desc'
        )
        # modifier
        resp = auth_client.put(
            f'/api/tontines/{tontine.id}/regles/{regle.id}/',
            {'titre': 'Nouveau'}, format='json',
        )
        assert resp.status_code == 200
        regle.refresh_from_db()
        assert regle.titre == 'Nouveau'
        # supprimer
        resp = auth_client.delete(f'/api/tontines/{tontine.id}/regles/{regle.id}/')
        assert resp.status_code == 204
        assert not RegleTontine.objects.filter(id=regle.id).exists()
