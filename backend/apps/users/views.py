from rest_framework import views, permissions, status, generics
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model
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
    password = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True)
    language = serializers.CharField(write_only=True, required=False, allow_blank=True, default='fr')
    location = serializers.CharField(write_only=True, required=False, allow_blank=True, default='')
    role = serializers.ChoiceField(choices=User.ROLE_CHOICES, write_only=True, required=False, default='farmer')
    region = serializers.CharField(write_only=True, required=False, allow_blank=True, allow_null=True, default=None)
    primary_crops = serializers.ListField(
        child=serializers.CharField(),
        write_only=True,
        required=False,
        default=list
    )

    class Meta:
        model = User
        fields = ('phone_number', 'full_name', 'password', 'confirm_password', 'language', 'location', 'role', 'region', 'primary_crops')

    def validate_phone_number(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("Un utilisateur avec ce numéro de téléphone existe déjà.")
        return value

    def validate(self, attrs):
        if attrs['password'] != attrs.pop('confirm_password'):
            raise serializers.ValidationError({'confirm_password': 'Les mots de passe ne correspondent pas.'})
        return attrs

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['phone_number'],
            phone=validated_data['phone_number'],
            password=validated_data['password'],
            first_name=validated_data['full_name'],
            language=validated_data.get('language', 'fr'),
            location=validated_data.get('location', ''),
            role=validated_data.get('role', 'farmer'),
            region=validated_data.get('region'),
            primary_crops=validated_data.get('primary_crops', []),
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

class UpdateProfileView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, *args, **kwargs):
        user = request.user
        language = request.data.get('language')
        location = request.data.get('location')
        
        if language is not None:
            user.language = language
        if location is not None:
            user.location = location
            
        user.save()
        return Response({"status": "Profil mis à jour avec succès."})

