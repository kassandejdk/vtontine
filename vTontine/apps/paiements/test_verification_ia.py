import io
from unittest.mock import patch

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile

from apps.tontines.models import Participation
from apps.paiements.models import Paiement
from apps.paiements.verification_ia import verifier_paiement, _normaliser_telephone


def _image_test():
    from PIL import Image
    buf = io.BytesIO()
    Image.new('RGB', (10, 10), color='white').save(buf, format='PNG')
    buf.seek(0)
    return SimpleUploadedFile('preuve.png', buf.read(), content_type='image/png')


@pytest.fixture
def tontine_avec_membre(make_tontine, make_user):
    tontine = make_tontine()
    membre = make_user()
    participation = Participation.objects.create(
        tontine=tontine, participant=membre, statut='CONFIRME', ordre_prise=1
    )
    return tontine, membre, participation


class TestNormaliserTelephone:
    def test_ignore_indicatif_pays(self):
        assert _normaliser_telephone('+22670123456') == _normaliser_telephone('70123456')

    def test_valeur_vide(self):
        assert _normaliser_telephone(None) == ''
        assert _normaliser_telephone('') == ''


class TestVerifierPaiement:
    @patch('apps.paiements.verification_ia.extraire_infos_paiement')
    def test_concordant_quand_montant_et_numero_correspondent(self, mock_extraire):
        mock_extraire.return_value = {
            'montant': 5000, 'numero_destinataire': '70123456', 'lisible': True,
        }
        statut, details = verifier_paiement(
            montant_attendu=5000, numero_attendu='70123456', image_file=io.BytesIO()
        )
        assert statut == 'CONCORDANT'
        assert details['montant_ok'] is True
        assert details['numero_ok'] is True

    @patch('apps.paiements.verification_ia.extraire_infos_paiement')
    def test_divergent_quand_montant_different(self, mock_extraire):
        mock_extraire.return_value = {
            'montant': 3000, 'numero_destinataire': '70123456', 'lisible': True,
        }
        statut, details = verifier_paiement(
            montant_attendu=5000, numero_attendu='70123456', image_file=io.BytesIO()
        )
        assert statut == 'DIVERGENT'
        assert details['montant_ok'] is False
        assert details['numero_ok'] is True

    @patch('apps.paiements.verification_ia.extraire_infos_paiement')
    def test_divergent_quand_numero_different(self, mock_extraire):
        mock_extraire.return_value = {
            'montant': 5000, 'numero_destinataire': '76000000', 'lisible': True,
        }
        statut, details = verifier_paiement(
            montant_attendu=5000, numero_attendu='70123456', image_file=io.BytesIO()
        )
        assert statut == 'DIVERGENT'
        assert details['numero_ok'] is False

    @patch('apps.paiements.verification_ia.extraire_infos_paiement')
    def test_non_verifiable_quand_image_illisible(self, mock_extraire):
        mock_extraire.return_value = {'montant': None, 'numero_destinataire': None, 'lisible': False}
        statut, _ = verifier_paiement(
            montant_attendu=5000, numero_attendu='70123456', image_file=io.BytesIO()
        )
        assert statut == 'NON_VERIFIABLE'

    @patch('apps.paiements.verification_ia.extraire_infos_paiement')
    def test_non_verifiable_quand_extraction_echoue(self, mock_extraire):
        mock_extraire.return_value = None
        statut, details = verifier_paiement(
            montant_attendu=5000, numero_attendu='70123456', image_file=io.BytesIO()
        )
        assert statut == 'NON_VERIFIABLE'
        assert details == {}

    @patch('apps.paiements.verification_ia.extraire_infos_paiement')
    def test_non_verifiable_quand_montant_manquant(self, mock_extraire):
        mock_extraire.return_value = {
            'montant': None, 'numero_destinataire': '70123456', 'lisible': True,
        }
        statut, _ = verifier_paiement(
            montant_attendu=5000, numero_attendu='70123456', image_file=io.BytesIO()
        )
        assert statut == 'NON_VERIFIABLE'


@pytest.mark.django_db
class TestVerificationDeclencheeALaCreation:
    @patch('apps.paiements.views.verifier_paiement')
    def test_verification_appelee_si_piece_jointe(self, mock_verifier, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        mock_verifier.return_value = ('CONCORDANT', {'montant_ok': True, 'numero_ok': True})
        api_client.force_authenticate(user=membre)

        resp = api_client.post('/api/paiements/', {
            'participation': participation.id,
            'montant': 5000,
            'piece_jointe': _image_test(),
        }, format='multipart')

        assert resp.status_code == 201
        mock_verifier.assert_called_once()
        _, kwargs = mock_verifier.call_args
        assert kwargs['montant_attendu'] == tontine.montant
        assert kwargs['numero_attendu'] == tontine.createur.telephone

        paiement = Paiement.objects.get(id=resp.data['id'])
        assert paiement.verification_ia_statut == 'CONCORDANT'
        assert resp.data['verification_ia_statut'] == 'CONCORDANT'

    @patch('apps.paiements.views.verifier_paiement')
    def test_pas_de_verification_sans_piece_jointe(self, mock_verifier, api_client, tontine_avec_membre):
        tontine, membre, participation = tontine_avec_membre
        api_client.force_authenticate(user=membre)

        resp = api_client.post('/api/paiements/', {
            'participation': participation.id, 'montant': 5000,
        }, format='json')

        assert resp.status_code == 201
        mock_verifier.assert_not_called()
        assert resp.data['verification_ia_statut'] == 'NON_VERIFIE'
