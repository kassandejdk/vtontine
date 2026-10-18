from rest_framework import serializers
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    tontine_id = serializers.IntegerField(read_only=True)

    class Meta:
        model = Notification
        fields = [
            'id', 'titre', 'message', 'date_envoie', 'est_lu',
            'tontine_id', 'invitation_token',
        ]
        read_only_fields = [
            'id', 'titre', 'message', 'date_envoie',
            'tontine_id', 'invitation_token',
        ]
