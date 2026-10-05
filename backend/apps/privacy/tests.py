from datetime import date

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APIClient

from apps.agriculture.models import Activity, Crop, PestReport
from apps.ai_assistant.models import AIInteraction
from apps.finances.models import Sale, Transaction
from apps.inventory.models import StockItem
from apps.notifications.models import Notification
from apps.privacy.policy import POLICY_VERSION

User = get_user_model()

POLICY = '/api/privacy/policy/'
EXPORT = '/api/privacy/export/'
DELETE = '/api/privacy/delete-account/'
REGISTER = '/api/users/auth/register/'
STRONG = 'Motdepasse#2026'


def make_user(phone, name='Ali'):
    return User.objects.create_user(username=phone, phone=phone, password=STRONG, first_name=name, location='Thiès')


def populate(user):
    """Une donnée de chaque type rattachée à l'utilisateur."""
    crop = Crop.objects.create(
        user=user, name='Mil', crop_type='Mil', planting_date='2026-06-01',
        expected_harvest_date='2026-10-01', area_size=2.0, location='Thiès')
    Activity.objects.create(crop=crop, activity_type='Semis', description='', date=date(2026, 6, 2))
    Sale.objects.create(crop=crop, quantity_sold=10, price_per_unit=300, date=date(2026, 10, 1))
    Transaction.objects.create(user=user, transaction_type='expense', amount=5000, date=date(2026, 6, 3), description='Semences')
    StockItem.objects.create(user=user, name='Mil', quantity=50, unit='kg')
    Notification.objects.create(user=user, type='weather', message='Pluie demain')
    PestReport.objects.create(user=user, pest_name='Chenille', location='Thiès')
    AIInteraction.objects.create(user=user, query='Quand semer ?', response='En juin.')


class PolicyTests(TestCase):
    def test_policy_is_public_and_versioned(self):
        response = APIClient().get(POLICY)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(data['version'], POLICY_VERSION)
        self.assertEqual(data['language'], 'fr')
        self.assertIn('Politique de confidentialité', data['content'])


class ConsentTests(TestCase):
    payload = {'phone_number': '+221775556677', 'full_name': 'Fatou Sow', 'password': STRONG}

    def test_acceptance_is_recorded_with_the_policy_version(self):
        response = APIClient().post(REGISTER, {**self.payload, 'privacy_accepted': True}, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        user = User.objects.get(phone='+221775556677')
        self.assertIsNotNone(user.privacy_accepted_at)
        self.assertEqual(user.privacy_policy_version, POLICY_VERSION)

    def test_registration_without_consent_is_still_allowed_by_default(self):
        response = APIClient().post(REGISTER, self.payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIsNone(User.objects.get().privacy_accepted_at)

    @override_settings(PRIVACY_CONSENT_REQUIRED=True)
    def test_consent_can_be_made_mandatory(self):
        refused = APIClient().post(REGISTER, self.payload, format='json')
        self.assertEqual(refused.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('privacy_accepted', refused.json())
        self.assertEqual(User.objects.count(), 0)

        accepted = APIClient().post(REGISTER, {**self.payload, 'privacy_accepted': True}, format='json')
        self.assertEqual(accepted.status_code, status.HTTP_201_CREATED)


class ExportTests(TestCase):
    def setUp(self):
        self.ali = make_user('+221770100101')
        self.binta = make_user('+221770100102', 'Binta')
        populate(self.ali)
        populate(self.binta)
        self.client = APIClient()
        self.client.force_authenticate(self.ali)

    def test_requires_authentication(self):
        self.assertEqual(APIClient().get(EXPORT).status_code, status.HTTP_401_UNAUTHORIZED)

    def test_export_contains_every_category_of_own_data(self):
        response = self.client.get(EXPORT)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('attachment', response['Content-Disposition'])
        data = response.json()
        self.assertEqual(data['profile']['phone'], '+221770100101')
        for key in ('crops', 'activities', 'pest_reports', 'sales', 'transactions',
                    'stock_items', 'notifications', 'ai_interactions'):
            self.assertEqual(len(data[key]), 1, key)

    def test_export_never_leaks_another_users_data(self):
        text = self.client.get(EXPORT).content.decode()
        self.assertNotIn('+221770100102', text)
        self.assertNotIn('Binta', text)

    def test_export_never_contains_password_hash(self):
        text = self.client.get(EXPORT).content.decode()
        self.assertNotIn('pbkdf2', text)
        self.assertNotIn('md5$', text)
        self.assertNotIn('"password"', text)


class DeleteAccountTests(TestCase):
    def setUp(self):
        self.ali = make_user('+221770100201')
        self.binta = make_user('+221770100202', 'Binta')
        populate(self.ali)
        populate(self.binta)
        self.client = APIClient()
        self.client.force_authenticate(self.ali)

    def test_requires_authentication(self):
        self.assertEqual(APIClient().post(DELETE, {'password': STRONG}, format='json').status_code,
                         status.HTTP_401_UNAUTHORIZED)

    def test_wrong_password_deletes_nothing(self):
        response = self.client.post(DELETE, {'password': 'faux'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertTrue(User.objects.filter(pk=self.ali.pk).exists())

    def test_missing_password_deletes_nothing(self):
        self.assertEqual(self.client.post(DELETE, {}, format='json').status_code, status.HTTP_400_BAD_REQUEST)
        self.assertTrue(User.objects.filter(pk=self.ali.pk).exists())

    def test_deletion_erases_account_and_all_linked_data(self):
        response = self.client.post(DELETE, {'password': STRONG}, format='json')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)

        self.assertFalse(User.objects.filter(pk=self.ali.pk).exists())
        for model in (Crop, Activity, Sale, Transaction, StockItem, Notification, PestReport, AIInteraction):
            self.assertEqual(model.objects.count(), 1, f'{model.__name__} : seules les données de Binta doivent rester')

    def test_deletion_does_not_touch_other_accounts(self):
        self.client.post(DELETE, {'password': STRONG}, format='json')
        self.assertTrue(User.objects.filter(pk=self.binta.pk).exists())
        self.assertEqual(Crop.objects.get().user, self.binta)

    def test_staff_account_cannot_be_deleted_from_the_app(self):
        staff = User.objects.create_user(username='staff', password=STRONG, is_staff=True)
        client = APIClient()
        client.force_authenticate(staff)
        response = client.post(DELETE, {'password': STRONG}, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(User.objects.filter(pk=staff.pk).exists())
