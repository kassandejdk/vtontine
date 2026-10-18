from django.db import models
from django.conf import settings


class Notification(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    message = models.TextField()
    titre = models.CharField(max_length=200)
    date_envoie = models.DateTimeField(auto_now_add=True)
    est_lu = models.BooleanField(default=False)

    # Lien optionnel vers une tontine/invitation, pour rendre la notification actionnable
    tontine = models.ForeignKey(
        'tontines.Tontine',
        on_delete=models.CASCADE,
        null=True, blank=True,
        related_name='notifications'
    )
    invitation_token = models.UUIDField(null=True, blank=True)

    class Meta:
        verbose_name = 'Notification'
        ordering = ['-date_envoie']

    def __str__(self):
        lu = "✓" if self.est_lu else "●"
        return f"{lu} {self.titre} → {self.user}"