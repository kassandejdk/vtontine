from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models

class UserManager(BaseUserManager):
    def create_user(self, telephone, password=None, **extra_fields):
        if not telephone:
            raise ValueError('Le numéro de téléphone est obligatoire')
        user = self.model(telephone=telephone, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, telephone, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(telephone, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    """
    Modèle User du diagramme de classes.
    keycloak_id = l'ID unique retourné par Keycloak (sub dans le token JWT)
    """
    GENRE_CHOICES = [
        ('H', 'Homme'),
        ('F', 'Femme'),
    ]

    # Champs du diagramme
    nom = models.CharField(max_length=100)
    prenom = models.CharField(max_length=100)
    telephone = models.CharField(max_length=20, unique=True)
    genre = models.CharField(max_length=1, choices=GENRE_CHOICES)

    # Champ Keycloak : lien entre notre User et le compte Keycloak
    keycloak_id = models.CharField(max_length=255, unique=True, null=True, blank=True)

    # Raccourci de paiement Mobile Money personnalisé (USSD), avec {montant} comme
    # emplacement du montant. Ex. "*144*2*1*{montant}#". Vide = non configuré.
    code_paiement_ussd = models.CharField(max_length=100, blank=True, default='')

    # Photo de profil (facultative)
    photo = models.ImageField(upload_to='avatars/', null=True, blank=True)

    # Champs Django standard
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_creation = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = 'telephone'
    REQUIRED_FIELDS = ['nom', 'prenom', 'genre']

    class Meta:
        verbose_name = 'Utilisateur'
        verbose_name_plural = 'Utilisateurs'

    def __str__(self):
        return f"{self.prenom} {self.nom} ({self.telephone})"
