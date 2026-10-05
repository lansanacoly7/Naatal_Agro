from django.apps import apps
from django.contrib import admin
from django.contrib.auth import get_user_model
from django.test import RequestFactory, TestCase
from django.urls import reverse

User = get_user_model()

LOCAL_APPS = ('users', 'agriculture', 'markets', 'weather', 'notifications', 'ai_assistant', 'inventory', 'finances')


def project_models():
    return [model for label in LOCAL_APPS for model in apps.get_app_config(label).get_models()]


class AdminTests(TestCase):
    def setUp(self):
        self.admin_user = User.objects.create_superuser(
            username='admin', email='admin@naatal.sn', password='Motdepasse#2026')
        self.client.force_login(self.admin_user)

    def test_every_project_model_is_registered(self):
        missing = [m.__name__ for m in project_models() if not admin.site.is_registered(m)]
        self.assertEqual(missing, [])

    def test_every_model_admin_has_filters_and_search(self):
        for model in project_models():
            model_admin = admin.site._registry[model]
            self.assertTrue(model_admin.search_fields, f'{model.__name__} : search_fields manquant')
            self.assertTrue(
                model_admin.list_filter or model_admin.date_hierarchy,
                f'{model.__name__} : aucun filtre',
            )

    def test_every_changelist_loads(self):
        for model in project_models():
            url = reverse(f'admin:{model._meta.app_label}_{model._meta.model_name}_changelist')
            response = self.client.get(url)
            self.assertEqual(response.status_code, 200, f'{model.__name__} : {response.status_code}')

    def test_ai_interactions_are_read_only(self):
        from apps.ai_assistant.models import AIInteraction
        model_admin = admin.site._registry[AIInteraction]
        request = RequestFactory().get('/admin/')
        request.user = self.admin_user
        self.assertFalse(model_admin.has_add_permission(request))
        self.assertFalse(model_admin.has_change_permission(request))

    def test_search_works_on_users(self):
        url = reverse('admin:users_user_changelist')
        self.assertEqual(self.client.get(url, {'q': 'admin'}).status_code, 200)
