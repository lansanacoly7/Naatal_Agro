from rest_framework import views, permissions, status, generics
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.response import Response
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken

from .phone import clean_phone, normalize_phone

User = get_user_model()

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Remplace 'username' par 'phone_number' dans les champs attendus
        self.fields['phone_number'] = serializers.CharField()
        del self.fields[self.username_field]

    def validate(self, attrs):
        # Mappe phone_number vers username pour que simple_jwt fonctionne
        attrs[self.username_field] = clean_phone(attrs.pop('phone_number'))
        data = super().validate(attrs)
        
        # Add user details to response
        data['role'] = self.user.role
        data['location'] = self.user.location
        data['full_name'] = self.user.first_name
        
        return data

class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth'

class RegisterSerializer(serializers.ModelSerializer):
    phone_number = serializers.CharField(write_only=True)
    full_name = serializers.CharField(write_only=True)
    password = serializers.CharField(write_only=True)
    language = serializers.CharField(write_only=True, required=False)
    location = serializers.CharField(write_only=True, required=False)
    # Un compte administrateur ne se crée jamais par l'inscription publique
    role = serializers.ChoiceField(choices=[('farmer', 'Agriculteur')], write_only=True, required=False, default='farmer')
    email = serializers.EmailField(write_only=True, required=False, allow_blank=True)
    date_of_birth = serializers.DateField(write_only=True, required=False, allow_null=True)
    main_crops = serializers.JSONField(write_only=True, required=False, default=list)

    class Meta:
        model = User
        fields = ('phone_number', 'full_name', 'password', 'language', 'location', 'role', 'email', 'date_of_birth', 'main_crops')

    def validate_phone_number(self, value):
        try:
            cleaned = normalize_phone(value)
        except ValueError as exc:
            raise serializers.ValidationError(str(exc))
        if User.objects.filter(username=cleaned).exists() or User.objects.filter(phone=cleaned).exists():
            raise serializers.ValidationError("Ce numéro de téléphone est déjà associé à un compte.")
        return cleaned

    def validate(self, attrs):
        # Le validateur de similarité compare le mot de passe aux données du compte futur
        candidate = User(
            username=attrs['phone_number'],
            phone=attrs['phone_number'],
            first_name=attrs.get('full_name', ''),
            email=attrs.get('email', ''),
        )
        try:
            validate_password(attrs['password'], user=candidate)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({'password': list(exc.messages)})
        return attrs

    def validate_main_crops(self, value):
        if not isinstance(value, list):
            raise serializers.ValidationError("Le champ 'main_crops' doit être une liste de cultures.")
        return [str(c).strip() for c in value if str(c).strip()]

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['phone_number'],
            phone=validated_data['phone_number'],
            password=validated_data['password'],
            first_name=validated_data['full_name'],
            language=validated_data.get('language', 'fr'),
            location=validated_data.get('location', ''),
            role=validated_data.get('role', 'farmer'),
            email=validated_data.get('email', ''),
            date_of_birth=validated_data.get('date_of_birth'),
            main_crops=validated_data.get('main_crops', [])
        )
        return user

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth'
    serializer_class = RegisterSerializer

class UpdateFCMTokenView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        token = request.data.get('fcm_token')
        if not token:
            return Response({"error": "Le paramètre 'fcm_token' est requis."}, status=status.HTTP_400_BAD_REQUEST)
        
        user = request.user
        user.fcm_token = token
        user.save()
        return Response({"status": "Token mis à jour avec succès."})

class UserProfileSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()
    crops_count = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            'id',
            'phone',
            'username',
            'email',
            'first_name',
            'last_name',
            'full_name',
            'role',
            'location',
            'language',
            'date_of_birth',
            'main_crops',
            'date_joined',
            'crops_count',
        )
        # Le téléphone est l'identifiant de connexion : il ne se modifie pas par le profil
        read_only_fields = ('id', 'username', 'phone', 'role', 'date_joined', 'crops_count')

    def get_full_name(self, obj):
        name = f"{obj.first_name} {obj.last_name}".strip()
        return name if name else obj.first_name or obj.username

    def get_crops_count(self, obj):
        if hasattr(obj, 'crops'):
            return obj.crops.count()
        return len(obj.main_crops or [])

    def validate_main_crops(self, value):
        if not isinstance(value, list):
            raise serializers.ValidationError("Le champ 'main_crops' doit être une liste de cultures.")
        return [str(c).strip() for c in value if str(c).strip()]

class MeView(views.APIView):
    """
    Endpoint retournant ou mettant à jour les données complètes de l'utilisateur connecté.
    Supporte GET et PATCH.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        serializer = UserProfileSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def patch(self, request, *args, **kwargs):
        user = request.user
        serializer = UserProfileSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class UpdateProfileView(views.APIView):
    """
    Endpoint compatible rétroactivement avec l'ancien contrat /profile/update/.
    Utilise le même UserProfileSerializer validé.
    """
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, *args, **kwargs):
        user = request.user
        serializer = UserProfileSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                "status": "Profil mis à jour avec succès.",
                "user": serializer.data
            }, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LogoutView(views.APIView):
    """
    Déconnexion : invalide (liste noire) le jeton de rafraîchissement envoyé par le mobile.
    Après cet appel, ce jeton ne peut plus servir à obtenir un nouvel accès.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        refresh = request.data.get('refresh')
        if not refresh or not isinstance(refresh, str):
            return Response({"error": "Le paramètre 'refresh' est requis."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            token = RefreshToken(refresh)
        except TokenError:
            return Response({"error": "Jeton de rafraîchissement invalide ou expiré."}, status=status.HTTP_400_BAD_REQUEST)
        if str(token.get('user_id')) != str(request.user.pk):
            return Response({"error": "Ce jeton n'appartient pas à l'utilisateur connecté."}, status=status.HTTP_403_FORBIDDEN)
        token.blacklist()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True)

    def validate_old_password(self, value):
        if not self.context['request'].user.check_password(value):
            raise serializers.ValidationError("Mot de passe actuel incorrect.")
        return value

    def validate(self, attrs):
        user = self.context['request'].user
        if attrs['old_password'] == attrs['new_password']:
            raise serializers.ValidationError({'new_password': ["Le nouveau mot de passe doit être différent de l'actuel."]})
        try:
            validate_password(attrs['new_password'], user=user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({'new_password': list(exc.messages)})
        return attrs


class ChangePasswordView(views.APIView):
    """
    Changement de mot de passe. Toutes les sessions ouvertes (jetons de rafraîchissement
    en circulation) sont invalidées : l'appelant doit se reconnecter avec le nouveau mot de passe.
    """
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth'

    def post(self, request, *args, **kwargs):
        serializer = ChangePasswordSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        user = request.user
        user.set_password(serializer.validated_data['new_password'])
        user.save(update_fields=['password'])
        for outstanding in OutstandingToken.objects.filter(user=user):
            BlacklistedToken.objects.get_or_create(token=outstanding)
        return Response(status=status.HTTP_204_NO_CONTENT)
