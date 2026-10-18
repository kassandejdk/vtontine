from django.db import models
from django.conf import settings
import uuid
from django.utils import timezone
from datetime import timedelta

class Tontine(models.Model):
    FREQUENCE_TYPE_CHOICES = [
        ('JOUR', 'Jours'),
        ('SEMAINE', 'Semaines'),
        ('MOIS', 'Mois'),
    ]

    STATUT_CHOICES = [
        ('INCOMPLET', 'Incomplet'),
        ('COMPLET', 'Complet'),
        ('TERMINE', 'Terminé'),
    ]
    
    TYPE_PRISE_CHOICES = [
        ('ARGENT', 'Argent uniquement'),
        ('PRODUIT', 'Produit uniquement'),
        ('MIXTE', 'Argent + Produit'),
    ]

    nom = models.CharField(max_length=200)
    # accepter les conditions d'utilisations / regles avant d'etre accepter dans la tontine
    description = models.TextField(blank=True)
    frequence_valeur = models.IntegerField(default=1)  
    frequence_type = models.CharField(
        max_length=10,
        choices=FREQUENCE_TYPE_CHOICES,
        default='MOIS'
    )  

    nbre_participant = models.IntegerField()
    montant = models.DecimalField(max_digits=12, decimal_places=2)
    statut = models.CharField(
        max_length=20,
        choices=STATUT_CHOICES,
        default='INCOMPLET'
    ) # si le nombre de participant est atteint, le statut passe a actif, et si la date de debut est atteinte, le statut passe a termine
    visibilite = models.BooleanField(default=True)  # True = visible dans la liste publique, False = non visible
    createur = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='tontines_creees'
    )
    createur_est_membre = models.BooleanField(
        default=False,
        help_text="Si True, le créateur est compté comme participant actif"
    )
    date_creation = models.DateTimeField(auto_now_add=True)
    date_debut = models.DateField(null=True, blank=True)
    
    type_prise = models.CharField(
        max_length=10,
        choices=TYPE_PRISE_CHOICES,
        default='ARGENT',
        help_text="Définit la nature de ce que reçoit le bénéficiaire à chaque tour"
    )
    montant_prise = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Montant en argent de la prise (si type ARGENT ou MIXTE)"
    )
    description_produit_prise = models.TextField(
        blank=True,
        help_text="Description du produit/objet remis (pagnes, consommables...) si type PRODUIT ou MIXTE"
    )
    valeur_estimee_produit = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Valeur estimée du produit pour information (facultatif)"
    )

    def __str__(self):
        return f"{self.nom} - tous les {self.frequence_valeur} {self.get_frequence_type_display()}"

    @property
    def frequence_display(self):
        return f"tous les {self.frequence_valeur} {self.get_frequence_type_display()}"

    @property
    def nombre_places_restantes(self):
        """Tient compte du créateur s'il est membre."""
        membres_confirmes = self.participations.filter(statut='CONFIRME').count()
        return self.nbre_participant - membres_confirmes

    @property
    def prise_display(self):
        """Résumé lisible de la prise."""
        if self.type_prise == 'ARGENT':
            return f"{self.montant_prise} FCFA" if self.montant_prise else "Non défini"
        elif self.type_prise == 'PRODUIT':
            return self.description_produit_prise
        else:  # MIXTE
            parts = []
            if self.montant_prise:
                parts.append(f"{self.montant_prise} FCFA")
            if self.description_produit_prise:
                parts.append(self.description_produit_prise)
            return " + ".join(parts) if parts else "Non défini"

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        super().save(*args, **kwargs)

        # À la création, si le créateur choisit d'être membre,
        # on crée automatiquement sa participation confirmée
        if is_new and self.createur_est_membre:
            Participation.objects.get_or_create(
                tontine=self,
                participant=self.createur,
                defaults={'statut': 'CONFIRME', 'est_createur': True, 'ordre_prise': 1}
            )
            self.recalculer_statut()

    def recalculer_statut(self):
        """Met à jour INCOMPLET <-> COMPLET selon les places restantes (ne touche jamais TERMINE)."""
        if self.statut == 'TERMINE':
            return
        nouveau_statut = 'COMPLET' if self.nombre_places_restantes <= 0 else 'INCOMPLET'
        if nouveau_statut != self.statut:
            self.statut = nouveau_statut
            self.save(update_fields=['statut'])

    def clean(self):
        from django.core.exceptions import ValidationError
        if self.type_prise in ('ARGENT', 'MIXTE') and not self.montant_prise:
            raise ValidationError(
                "Un montant de prise est requis pour le type %(type)s.",
                params={'type': self.get_type_prise_display()}
            )
        if self.type_prise in ('PRODUIT', 'MIXTE') and not self.description_produit_prise:
            raise ValidationError(
                "Une description du produit est requise pour le type %(type)s.",
                params={'type': self.get_type_prise_display()}
            )

    class Meta:
        verbose_name = 'Tontine'

class RegleTontine(models.Model):
    CATEGORIE_CHOICES = [
        ('ADHESION', 'Critère d\'adhésion'),
        ('COMPORTEMENT', 'Règle de comportement'),
        ('FINANCIER', 'Règle financière'),
        ('AUTRE', 'Autre'),
    ]

    tontine = models.ForeignKey(
        Tontine,
        on_delete=models.CASCADE,
        related_name='regles'
    )
    titre = models.CharField(max_length=200)
    description = models.TextField()
    categorie = models.CharField(
        max_length=20,
        choices=CATEGORIE_CHOICES,
        default='ADHESION'
    )
    ordre = models.PositiveIntegerField(default=0)  # pour trier l'affichage
    est_obligatoire = models.BooleanField(default=True)  # True = doit être acceptée pour rejoindre

    class Meta:
        verbose_name = 'Règle de tontine'
        verbose_name_plural = 'Règles de tontine'
        ordering = ['ordre', 'id']

    def __str__(self):
        return f"[{self.get_categorie_display()}] {self.titre}"


class AcceptationRegle(models.Model):
    """Trace l'acceptation explicite de chaque règle par chaque participant."""
    participant = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='acceptations_regles'
    )
    regle = models.ForeignKey(
        RegleTontine,
        on_delete=models.CASCADE,
        related_name='acceptations'
    )
    date_acceptation = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Acceptation de règle'
        unique_together = ('participant', 'regle') 

    def __str__(self):
        return f"{self.participant} a accepté : {self.regle.titre}"
    
class Participation(models.Model):
    """Membres d'une tontine (incluant éventuellement le créateur)."""

    STATUT_CHOICES = [
        ('EN_ATTENTE', 'En attente de confirmation'),
        ('CONFIRME', 'Confirmé'),
        ('EXCLU', 'Exclu'),
    ]

    tontine = models.ForeignKey(
        Tontine,
        on_delete=models.CASCADE,
        related_name='participations'
    )
    participant = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='participations'
    )
    statut = models.CharField(
        max_length=20,
        choices=STATUT_CHOICES,
        default='EN_ATTENTE'
    )
    est_createur = models.BooleanField(
        default=False,
        help_text="True si ce membre est aussi le créateur de la tontine"
    )
    ordre_prise = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Position dans l'ordre de passage pour recevoir la prise"
    )
    date_adhesion = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Participation'
        unique_together = ('tontine', 'participant')
        ordering = ['ordre_prise', 'date_adhesion']

    def __str__(self):
        role = " (créateur)" if self.est_createur else ""
        return f"{self.participant}{role} → {self.tontine.nom} [{self.get_statut_display()}]"
        
def expiration_defaut():
    return timezone.now() + timedelta(days=7)

class InvitationLien(models.Model):
    tontine     = models.ForeignKey(Tontine, on_delete=models.CASCADE, related_name='invitations_lien')
    token       = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    cree_par    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    cree_le     = models.DateTimeField(auto_now_add=True)
    expire_le   = models.DateTimeField(default=expiration_defaut)
    est_actif   = models.BooleanField(default=True)

    class Meta:
        ordering = ['-cree_le']

    def est_valide(self):
        return self.est_actif and timezone.now() < self.expire_le

    def __str__(self):
        return f"Lien {self.token} — {self.tontine.nom}"
    


class InvitationTontine(models.Model):
    STATUT_CHOICES = [
        ('EN_ATTENTE', 'En attente'),
        ('ACCEPTEE',   'Acceptée'),
        ('REFUSEE',    'Refusée'),
        ('EXPIREE',    'Expirée'),
    ]
    TYPE_CHOICES = [
        ('DIRECTE', 'Invitation directe (user existant)'),
        ('LIEN',    'Invitation par lien'),
    ]

    tontine      = models.ForeignKey(Tontine, on_delete=models.CASCADE, related_name='invitations')
    invite_par   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='invitations_envoyees')
    # Pour invitation directe
    invite       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='invitations_recues')
    # Pour invitation par lien
    email_invite = models.EmailField(blank=True)
    token        = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    type         = models.CharField(max_length=10, choices=TYPE_CHOICES)
    statut       = models.CharField(max_length=20, choices=STATUT_CHOICES, default='EN_ATTENTE')
    date_envoi   = models.DateTimeField(auto_now_add=True)
    date_expiration = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = 'Invitation'
        # Empêche d'inviter deux fois le même user dans la même tontine
        unique_together = [('tontine', 'invite')]

    def est_expiree(self):
        from django.utils import timezone
        return self.date_expiration and timezone.now() > self.date_expiration

    def __str__(self):
        cible = self.invite or self.email_invite
        return f"Invitation {self.type} → {cible} pour {self.tontine.nom} [{self.statut}]"


class MethodePaiement(models.Model):
    """
    Moyen de paiement défini par le créateur de la tontine.
    `code_ussd` peut contenir {montant} (remplacé par le montant à payer)
    et intègre le numéro du créateur, ex. "*144*10*70000000*{montant}#".
    """
    tontine = models.ForeignKey(
        Tontine, on_delete=models.CASCADE, related_name='methodes_paiement'
    )
    libelle = models.CharField(max_length=100)  # ex. "Orange Money"
    code_ussd = models.CharField(max_length=100)
    ordre = models.PositiveIntegerField(default=0)

    class Meta:
        verbose_name = 'Méthode de paiement'
        ordering = ['ordre', 'id']

    def __str__(self):
        return f"{self.libelle} ({self.code_ussd}) — {self.tontine.nom}"


class MessageTontine(models.Model):
    """Message dans la discussion de groupe d'une tontine (texte / image / audio)."""
    TYPE_CHOICES = [
        ('TEXTE', 'Texte'),
        ('IMAGE', 'Image'),
        ('AUDIO', 'Note vocale'),
    ]

    tontine = models.ForeignKey(
        Tontine, on_delete=models.CASCADE, related_name='messages'
    )
    auteur = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='messages_tontine'
    )
    contenu = models.TextField(blank=True, default='')  # texte ou légende
    type = models.CharField(max_length=10, choices=TYPE_CHOICES, default='TEXTE')
    piece_jointe = models.FileField(upload_to='messages/', null=True, blank=True)
    date_envoi = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Message de tontine'
        ordering = ['date_envoi']

    def __str__(self):
        return f"[{self.type}] {self.auteur} @ {self.tontine.nom}: {self.contenu[:30]}"


class DemandeAdhesion(models.Model):
    """Demande spontanée d'un user sur une tontine publique — doit être validée par le créateur."""
    STATUT_CHOICES = [
        ('EN_ATTENTE', 'En attente'),
        ('ACCEPTEE',   'Acceptée'),
        ('REFUSEE',    'Refusée'),
    ]

    tontine       = models.ForeignKey(Tontine, on_delete=models.CASCADE, related_name='demandes')
    demandeur     = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='demandes_adhesion')
    statut        = models.CharField(max_length=20, choices=STATUT_CHOICES, default='EN_ATTENTE')
    message       = models.TextField(blank=True, help_text="Message optionnel du demandeur")
    date_demande  = models.DateTimeField(auto_now_add=True)
    date_traitement = models.DateTimeField(null=True, blank=True)
    traite_par    = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='demandes_traitees'
    )

    class Meta:
        verbose_name = 'Demande d\'adhésion'
        unique_together = ('tontine', 'demandeur')  # une seule demande active par user

    def __str__(self):
        return f"{self.demandeur} → {self.tontine.nom} [{self.statut}]"


class Cycle(models.Model):
    """
    Un tour de la tontine (ex. un mois si la fréquence est mensuelle).

    À chaque cycle, tous les membres cotisent et un bénéficiaire reçoit la prise.
    Le cycle sert de registre : à quelle période on est, qui a payé pour ce tour,
    qui doit recevoir la prise et si elle a été versée.
    """
    STATUT_CHOICES = [
        ('A_VENIR', 'À venir'),
        ('EN_COURS', 'En cours'),
        ('CLOTURE', 'Clôturé'),
    ]

    tontine = models.ForeignKey(
        Tontine, on_delete=models.CASCADE, related_name='cycles'
    )
    numero = models.PositiveIntegerField(
        help_text="Rang du tour (1 = premier). Correspond à l'ordre_prise du bénéficiaire."
    )
    date_debut = models.DateField(null=True, blank=True)
    date_fin = models.DateField(null=True, blank=True)
    beneficiaire = models.ForeignKey(
        Participation,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='cycles_beneficies',
        help_text="Participation qui reçoit la prise à ce tour (ordre_prise == numero)."
    )
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default='A_VENIR')
    prise_versee = models.BooleanField(
        default=False,
        help_text="True quand la prise de ce cycle a été remise au bénéficiaire."
    )
    date_versement = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = 'Cycle'
        unique_together = ('tontine', 'numero')
        ordering = ['numero']

    def __str__(self):
        return f"{self.tontine.nom} — cycle {self.numero} [{self.get_statut_display()}]"