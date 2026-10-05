from rest_framework import permissions

class IsOwnerOrReadOnly(permissions.BasePermission):
    """
    Permission personnalisée :
    - Autorise les requêtes de lecture (GET, HEAD, OPTIONS) à tout utilisateur authentifié.
    - Restreint les opérations d'écriture (PUT, PATCH, DELETE) au propriétaire strict de la ressource.
    """
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        
        owner = getattr(obj, 'user', None) or getattr(obj, 'farmer', None)
        return owner == request.user
