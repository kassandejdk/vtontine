from django.db import models
from django.conf import settings
from apps.tontines.models import Participation


class Paiement(models.Model):
    """
    Correspond à la classe Paiement du diagramme.
    Relation : 1 Participation → 0..* Paiements
    """
    STATUT_CHOICES = [
        ('EN_ATTENTE', 'En attente'),
        ('CONFIRME', 'Confirmé'),
        ('REFUSE', 'Refusé'),
    ]

    VERIFICATION_IA_CHOICES = [
        ('NON_VERIFIE', 'Non vérifié'),
        ('CONCORDANT', 'Concordant'),
        ('DIVERGENT', 'Divergent'),
        ('NON_VERIFIABLE', 'Non vérifiable'),
    ]

    participation = models.ForeignKey(
        Participation,
        on_delete=models.CASCADE,
        related_name='paiements'
    )
    cycle = models.ForeignKey(
        'tontines.Cycle',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='paiements',
        help_text="Cycle (période) auquel se rattache ce paiement."
    )
    montant = models.DecimalField(max_digits=12, decimal_places=2)
    date_paiement = models.DateTimeField(auto_now_add=True)
    transaction_id = models.CharField(max_length=255, unique=True)
    piece_jointe = models.ImageField(
        upload_to='paiements/', null=True, blank=True,
        help_text="Capture d'écran / preuve de paiement (optionnelle)."
    )
    # Conservé pour compatibilité ; maintenu en phase avec `statut`.
    est_confirmer = models.BooleanField(default=False)
    statut = models.CharField(
        max_length=20, choices=STATUT_CHOICES, default='EN_ATTENTE'
    )

    # Vérification automatique (IA) de la pièce jointe, si fournie. Purement
    # indicative : elle aide le créateur à confirmer/refuser, elle ne remplace
    # pas sa décision.
    verification_ia_statut = models.CharField(
        max_length=20, choices=VERIFICATION_IA_CHOICES, default='NON_VERIFIE'
    )
    verification_ia_details = models.JSONField(null=True, blank=True)

    class Meta:
        verbose_name = 'Paiement'
        ordering = ['-date_paiement']

    def __str__(self):
        icone = {'CONFIRME': '✓', 'REFUSE': '✗'}.get(self.statut, '⏳')
        return f"{icone} {self.montant} FCFA - {self.transaction_id}"