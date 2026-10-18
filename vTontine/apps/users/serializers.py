from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    photo = serializers.SerializerMethodField()
    is_admin = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'nom', 'prenom', 'telephone', 'genre',
                  'code_paiement_ussd', 'photo', 'date_creation', 'is_admin']
        read_only_fields = ['id', 'date_creation', 'is_admin']

    def get_photo(self, obj):
        if not obj.photo:
            return None
        url = obj.photo.url
        request = self.context.get('request')
        return request.build_absolute_uri(url) if request else url

    def get_is_admin(self, obj):
        return bool(obj.is_staff or obj.is_superuser)


class AdminUserSerializer(UserSerializer):
    """Vue admin d'un utilisateur : ajoute l'activité et le statut du compte."""
    nb_tontines_creees = serializers.SerializerMethodField()

    class Meta(UserSerializer.Meta):
        fields = UserSerializer.Meta.fields + ['is_active', 'nb_tontines_creees']

    def get_nb_tontines_creees(self, obj):
        return obj.tontines_creees.count()


class UserUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['nom', 'prenom', 'genre', 'code_paiement_ussd']
        extra_kwargs = {
            'nom': {'required': False},
            'prenom': {'required': False},
            'genre': {'required': False},
        }

    def validate_nom(self, value):
        return value.strip()

    def validate_prenom(self, value):
        return value.strip()


class RegisterSerializer(serializers.Serializer):
    nom = serializers.CharField(max_length=100)
    prenom = serializers.CharField(max_length=100)
    telephone = serializers.CharField(max_length=20)
    password = serializers.CharField(min_length=8, write_only=True)
    genre = serializers.ChoiceField(choices=[('H', 'Homme'), ('F', 'Femme')])

    def validate_telephone(self, value):
        if User.objects.filter(telephone=value).exists():
            raise serializers.ValidationError('Ce numéro de téléphone est déjà utilisé')
        return value