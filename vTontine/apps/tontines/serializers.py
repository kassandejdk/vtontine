from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import Tontine, Participation, AcceptationRegle, InvitationTontine, DemandeAdhesion
from .models import Tontine, Participation, RegleTontine, MessageTontine, MethodePaiement, Cycle

User = get_user_model()

class UserMinimalSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'nom', 'prenom', 'telephone', 'full_name']

    def get_full_name(self, obj):
        return f"{obj.prenom} {obj.nom}"

class ParticipationSerializer(serializers.ModelSerializer):
    participant = UserMinimalSerializer(read_only=True)

    class Meta:
        model = Participation
        fields = ['id', 'participant', 'date_adhesion']

class RegleTontineSerializer(serializers.ModelSerializer):
    categorie_display = serializers.CharField(
        source='get_categorie_display', read_only=True
    )

    class Meta:
        model = RegleTontine
        fields = [
            'id', 'titre', 'description', 'categorie',
            'categorie_display', 'est_obligatoire', 'ordre',
        ]


class MethodePaiementSerializer(serializers.ModelSerializer):
    class Meta:
        model = MethodePaiement
        fields = ['id', 'libelle', 'code_ussd', 'ordre']
        read_only_fields = ['id']

class ParticipationSerializer(serializers.ModelSerializer):
    participant = UserMinimalSerializer(read_only=True)
    statut_display = serializers.CharField(
        source='get_statut_display', read_only=True
    )

    class Meta:
        model = Participation
        fields = [
            'id', 'participant', 'statut', 'statut_display',
            'est_createur', 'ordre_prise', 'date_adhesion',
        ]

class TontineSerializer(serializers.ModelSerializer):
    createur         = UserMinimalSerializer(read_only=True)
    frequence_display = serializers.ReadOnlyField()
    regles           = RegleTontineSerializer(many=True, read_only=True)
    methodes_paiement = MethodePaiementSerializer(many=True, read_only=True)

    # Champs calculés
    nbre_participants_actuels = serializers.SerializerMethodField()
    est_membre                = serializers.SerializerMethodField()
    est_createur              = serializers.SerializerMethodField()

    # Prise — labels lisibles
    type_prise_display = serializers.CharField(
        source='get_type_prise_display', read_only=True
    )
    prise_display = serializers.ReadOnlyField()  # property du modèle

    class Meta:
        model = Tontine
        fields = [
            # Infos générales
            'id', 'nom', 'description', 'statut',
            'visibilite', 'createur_est_membre',
            'createur', 'date_creation', 'date_debut',

            # Fréquence & participants
            'frequence_valeur', 'frequence_type', 'frequence_display',
            'nbre_participant', 'nbre_participants_actuels',

            # Cotisation
            'montant',

            # Prise
            'type_prise', 'type_prise_display',
            'montant_prise', 'description_produit_prise',
            'valeur_estimee_produit', 'prise_display',

            # Règles
            'regles',

            # Moyens de paiement (définis par le créateur)
            'methodes_paiement',

            # Contexte utilisateur connecté
            'est_membre', 'est_createur',
        ]
        read_only_fields = ['id', 'createur', 'date_creation', 'statut']

    def get_nbre_participants_actuels(self, obj):
        return obj.participations.filter(statut='CONFIRME').count()

    def get_est_membre(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.participations.filter(
                participant=request.user,
                statut='CONFIRME'
            ).exists()
        return False

    def get_est_createur(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.createur == request.user
        return False

class TontineCreateSerializer(serializers.ModelSerializer):
    """Serializer pour la création — accepte aussi les règles en nested."""
    regles = RegleTontineSerializer(many=True, required=False)

    class Meta:
        model = Tontine
        fields = [
            'nom', 'description', 'visibilite', 'createur_est_membre',
            'frequence_valeur', 'frequence_type',
            'nbre_participant', 'montant',
            'type_prise', 'montant_prise',
            'description_produit_prise', 'valeur_estimee_produit',
            'date_debut', 'regles',
        ]

    def validate(self, data):
        type_prise = data.get('type_prise', 'ARGENT')
        if type_prise in ('ARGENT', 'MIXTE') and not data.get('montant_prise'):
            raise serializers.ValidationError(
                {'montant_prise': 'Requis pour ce type de prise.'}
            )
        if type_prise in ('PRODUIT', 'MIXTE') and not data.get('description_produit_prise'):
            raise serializers.ValidationError(
                {'description_produit_prise': 'Requis pour ce type de prise.'}
            )
        return data

    def create(self, validated_data):
        regles_data = validated_data.pop('regles', [])
        tontine = Tontine.objects.create(**validated_data)

        # Créer les règles associées
        for i, regle_data in enumerate(regles_data):
            RegleTontine.objects.create(
                tontine=tontine,
                ordre=regle_data.get('ordre', i),
                **{k: v for k, v in regle_data.items() if k != 'ordre'}
            )

        return tontine

    def validate_nbre_participant(self, value):
        if value < 2:
            raise serializers.ValidationError(
                'Une tontine doit avoir au moins 2 participants'
            )
        return value

    def validate_montant(self, value):
        if value <= 0:
            raise serializers.ValidationError('Le montant doit être supérieur à 0')
        return value

    def validate_frequence_valeur(self, value):
        if value <= 0:
            raise serializers.ValidationError('La fréquence doit être supérieure à 0')
        return value

class DemandeAdhesionSerializer(serializers.ModelSerializer):
    demandeur = UserMinimalSerializer(read_only=True)
    tontine = TontineSerializer(read_only=True)

    class Meta:
        model = DemandeAdhesion
        fields = ['id', 'tontine', 'demandeur', 'message', 'statut', 'date_demande']
        read_only_fields = ['id', 'tontine', 'demandeur', 'statut', 'date_demande']


class DemandeAdhesionListSerializer(serializers.ModelSerializer):
    """Version légère (sans la tontine imbriquée) pour la liste côté créateur."""
    demandeur = UserMinimalSerializer(read_only=True)

    class Meta:
        model = DemandeAdhesion
        fields = ['id', 'demandeur', 'message', 'statut', 'date_demande']
        read_only_fields = ['id', 'demandeur', 'statut', 'date_demande']


class TontineUpdateSerializer(serializers.ModelSerializer):
    """Serializer pour la modification des champs légers d'une tontine (le statut
    est géré automatiquement par `Tontine.recalculer_statut()` ou via l'action
    explicite de fin de cycle, pas via ce serializer)."""

    class Meta:
        model = Tontine
        fields = ['nom', 'description', 'date_debut', 'visibilite']


class RegleTontineWriteSerializer(serializers.ModelSerializer):
    """Création / modification d'une règle (la tontine vient de l'URL)."""

    class Meta:
        model = RegleTontine
        fields = ['id', 'titre', 'description', 'categorie', 'est_obligatoire', 'ordre']
        read_only_fields = ['id']


class MessageTontineSerializer(serializers.ModelSerializer):
    auteur = UserMinimalSerializer(read_only=True)
    piece_jointe = serializers.SerializerMethodField()

    class Meta:
        model = MessageTontine
        fields = ['id', 'auteur', 'contenu', 'type', 'piece_jointe', 'date_envoi']
        read_only_fields = fields

    def get_piece_jointe(self, obj):
        if not obj.piece_jointe:
            return None
        url = obj.piece_jointe.url
        request = self.context.get('request')
        return request.build_absolute_uri(url) if request else url


class CycleBeneficiaireSerializer(serializers.ModelSerializer):
    """Le bénéficiaire d'un cycle = une participation + son user."""
    participant = UserMinimalSerializer(read_only=True)

    class Meta:
        model = Participation
        fields = ['id', 'participant', 'ordre_prise', 'est_createur']


class CycleSerializer(serializers.ModelSerializer):
    """Un tour de la tontine (période) pour le registre."""
    statut_display = serializers.CharField(source='get_statut_display', read_only=True)
    beneficiaire = CycleBeneficiaireSerializer(read_only=True)

    class Meta:
        model = Cycle
        fields = [
            'id', 'numero', 'date_debut', 'date_fin',
            'statut', 'statut_display', 'prise_versee', 'date_versement',
            'beneficiaire',
        ]
        read_only_fields = fields


class InvitationRecueSerializer(serializers.ModelSerializer):
    """Invitation directe reçue par l'utilisateur connecté."""
    tontine = TontineSerializer(read_only=True)
    invite_par = UserMinimalSerializer(read_only=True)
    statut_display = serializers.CharField(source='get_statut_display', read_only=True)

    class Meta:
        model = InvitationTontine
        fields = [
            'id', 'tontine', 'invite_par', 'type',
            'statut', 'statut_display', 'token',
            'date_envoi', 'date_expiration',
        ]
        read_only_fields = fields