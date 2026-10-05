from django.urls import path

from .views import DeleteAccountView, ExportDataView, PrivacyPolicyView

app_name = 'privacy'

urlpatterns = [
    path('policy/', PrivacyPolicyView.as_view(), name='policy'),
    path('export/', ExportDataView.as_view(), name='export'),
    path('delete-account/', DeleteAccountView.as_view(), name='delete_account'),
]
