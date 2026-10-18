import uuid

from rest_framework import serializers

from apps.tontines.models import Participation
from apps.tontines.serializers import UserMinimalSerializer
from apps.tontines.services import generer_cycles, cycle_courant
from .models import Paiement


class PaiementSerializer(serializers.ModelSerializer):
    """Représentation en lecture d'un paiement, enrichie du contexte tontine."""
    participant = UserMinimalSerializer(source='participation.participant', read_only=True)
    tontine_id = serializers.IntegerField(source='participation.tontine_id', read_only=True)
    tontine_nom = serializers.CharField(source='participation.tontine.nom', read_only=True)
    statut_display = serializers.CharField(source='get_statut_display', read_only=True)
    cycle_numero = serializers.IntegerField(
        source='cycle.numero', read_only=True, allow_null=True
    )
    verification_ia_statut_display = serializers.CharField(
        source='get_verification_ia_statut_display', read_only=True
    )

    class Meta:
        model = Paiement
        fields = [
            'id', 'participation', 'participant',
            'tontine_id', 'tontine_nom',
            'montant', 'date_paiement', 'transaction_id',
            'est_confirmer', 'statut', 'statut_display',
            'cycle', 'cycle_numero', 'piece_jointe',
            'verification_ia_statut', 'verification_ia_statut_display',
            'verification_ia_details',
        ]
        read_only_fields = fields


class PaiementCreateSerializer(serializers.ModelSerializer):
    """
    Enregistrement d'un paiement par un membre.

    `transaction_id` est facultatif : s'il n'est pas fourni (pas d'intégration
    Mobile Money réelle), on en génère un unique côté serveur.
    """

    class Meta:
        model = Paiement
        fields = ['participation', 'montant', 'transaction_id', 'piece_jointe']
        extra_kwargs = {
            'transaction_id': {'required': False, 'allow_blank': True},
            'piece_jointe': {'required': False, 'allow_null': True},
        }

    def validate_montant(self, value):
        if value <= 0:
            raise serializers.ValidationError('Le montant doit être supérieur à 0.')
        return value

    def validate_participation(self, participation):
        user = self.context['request'].user
        if participation.participant_id != user.id:
            raise serializers.ValidationError(
                "Vous ne pouvez enregistrer un paiement que pour votre propre participation."
            )
        if participation.statut != 'CONFIRME':
            raise serializers.ValidationError(
                "Vous devez être membre confirmé de la tontine pour cotiser."
            )
        if participation.tontine.statut == 'TERMINE':
            raise serializers.ValidationError("Cette tontine est terminée.")
        return participation

    def create(self, validated_data):
        if not validated_data.get('transaction_id'):
            validated_data['transaction_id'] = f"TXN-{uuid.uuid4().hex[:16].upper()}"
        # Rattache le paiement au cycle (période) en cours de la tontine.
        tontine = validated_data['participation'].tontine
        generer_cycles(tontine)
        validated_data['cycle'] = cycle_courant(tontine)
        return super().create(validated_data)
