"""
Vérification automatique (IA) des captures d'écran de paiement.

Principe : on envoie l'image jointe à Gemini avec une consigne d'extraction
stricte (montant + numéro de téléphone du destinataire), puis on compare le
résultat aux valeurs attendues (montant de la tontine, téléphone du créateur).

C'est une aide à la décision pour le créateur, pas une preuve : Gemini peut
se tromper, et rien n'empêche l'envoi d'une image retouchée ou réutilisée.
Le paiement reste `EN_ATTENTE` tant que le créateur ne l'a pas confirmé
manuellement, quel que soit le résultat de cette vérification.
"""
import json
import logging
from decimal import Decimal, InvalidOperation

from django.conf import settings
from PIL import Image

logger = logging.getLogger(__name__)

PROMPT_EXTRACTION = (
    "Tu analyses une capture d'écran de confirmation de paiement Mobile Money "
    "(Orange Money, Moov Money ou similaire). Réponds STRICTEMENT en JSON, "
    "sans aucun texte autour, avec ce format exact :\n"
    '{"montant": <montant transféré, nombre uniquement, sans devise ni espace, '
    'ou null si illisible>, "numero_destinataire": "<numéro de téléphone du '
    'destinataire du paiement, chiffres uniquement, ou null si illisible>", '
    '"lisible": <true si l\'image est bien une confirmation de paiement '
    'Mobile Money lisible, false sinon (image floue, hors-sujet, etc.)>}'
)


def _client():
    from google import genai
    return genai.Client(api_key=settings.GEMINI_API_KEY)


def extraire_infos_paiement(image_file):
    """
    Envoie l'image à Gemini et retourne un dict {montant, numero_destinataire,
    lisible}, ou None si l'appel n'a pas pu être fait (pas de clé API, erreur
    réseau, réponse invalide...).
    """
    if not settings.GEMINI_API_KEY:
        return None
    try:
        image_file.seek(0)
        image = Image.open(image_file)
        # Le client doit rester référencé pendant tout l'appel : un objet
        # temporaire (`_client().models...`) peut être garbage-collecté — et
        # fermer sa connexion HTTP sous-jacente — avant la fin d'une requête
        # avec retry, ce qui casse l'appel de façon intermittente.
        client = _client()
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=[PROMPT_EXTRACTION, image],
            config={'response_mime_type': 'application/json'},
        )
        data = json.loads(response.text)
        return {
            'montant': data.get('montant'),
            'numero_destinataire': data.get('numero_destinataire'),
            'lisible': bool(data.get('lisible')),
        }
    except Exception:
        logger.exception("Échec de l'extraction IA d'une capture de paiement.")
        return None


def _normaliser_telephone(numero):
    """Ne garde que les chiffres, et les 8 derniers (format téléphone BF) pour
    tolérer les indicatifs pays (+226, 00226...) éventuellement présents."""
    if not numero:
        return ''
    chiffres = ''.join(c for c in str(numero) if c.isdigit())
    return chiffres[-8:] if len(chiffres) >= 8 else chiffres


def verifier_paiement(*, montant_attendu, numero_attendu, image_file):
    """
    Extrait les infos de la capture puis les compare aux valeurs attendues.
    Retourne (statut, details) où statut est l'une des valeurs de
    Paiement.VERIFICATION_IA_CHOICES (hors 'NON_VERIFIE', valeur par défaut
    avant toute vérification).
    """
    infos = extraire_infos_paiement(image_file)
    if infos is None or not infos.get('lisible'):
        return 'NON_VERIFIABLE', (infos or {})

    montant_extrait = infos.get('montant')
    numero_extrait = infos.get('numero_destinataire')
    if montant_extrait is None or not numero_extrait:
        # Image jugée lisible par le modèle mais un des deux champs n'a pas
        # pu être extrait : on ne peut pas conclure, ce n'est pas pour
        # autant une divergence.
        return 'NON_VERIFIABLE', infos

    details = dict(infos)
    try:
        montant_ok = Decimal(str(montant_extrait)) == Decimal(str(montant_attendu))
    except (InvalidOperation, TypeError):
        montant_ok = False

    numero_ok = _normaliser_telephone(numero_extrait) == _normaliser_telephone(numero_attendu)

    details['montant_ok'] = montant_ok
    details['numero_ok'] = numero_ok

    statut = 'CONCORDANT' if (montant_ok and numero_ok) else 'DIVERGENT'
    return statut, details
