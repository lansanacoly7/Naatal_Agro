from rest_framework import views, permissions, status, generics
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

User = get_user_model()

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Remplace 'username' par 'phone_number' dans les champs attendus
        self.fields['phone_number'] = serializers.CharField()
        del self.fields[self.username_field]

    def validate(self, attrs):
        # Mappe phone_number vers username pour que simple_jwt fonctionne
        attrs[self.username_field] = attrs.pop('phone_number')
        data = super().validate(attrs)
        
        # Add user details to response
        data['role'] = self.user.role
        data['location'] = self.user.location
        data['full_name'] = self.user.first_name
        
        return data

class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer

class RegisterSerializer(serializers.ModelSerializer):
    phone_number = serializers.CharField(write_only=True)
    full_name = serializers.CharField(write_only=True)
    password = serializers.CharField(write_only=True)
    language = serializers.CharField(write_only=True, required=False)
    location = serializers.CharField(write_only=True, required=False)
    role = serializers.ChoiceField(choices=User.ROLE_CHOICES, write_only=True, required=False, default='farmer')
    email = serializers.EmailField(write_only=True, required=False, allow_blank=True)
    date_of_birth = serializers.DateField(write_only=True, required=False, allow_null=True)
    main_crops = serializers.JSONField(write_only=True, required=False, default=list)

    class Meta:
        model = User
        fields = ('phone_number', 'full_name', 'password', 'language', 'location', 'role', 'email', 'date_of_birth', 'main_crops')

    def validate_phone_number(self, value):
        cleaned = value.strip().replace(' ', '')
        if User.objects.filter(username=cleaned).exists() or User.objects.filter(phone=cleaned).exists():
            raise serializers.ValidationError("Ce numéro de téléphone est déjà associé à un compte.")
        return cleaned

    def validate_password(self, value):
        validate_password(value)
        return value

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
        read_only_fields = ('id', 'username', 'role', 'date_joined', 'crops_count')

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
