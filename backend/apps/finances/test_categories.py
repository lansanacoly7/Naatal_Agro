"""Classement des dépenses : règle déterministe, appliquée quel que soit le chemin d'écriture."""
import datetime

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase, TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.agriculture.models import Activity, Crop
from apps.finances.categories import CATEGORY_CODES, category_label, infer_expense_category
from apps.finances.models import Transaction

User = get_user_model()


class InferExpenseCategoryTests(SimpleTestCase):
    def test_known_labels(self):
        cases = {
            "Achat d'engrais urée": 'engrais',
            "Compost biologique": 'engrais',
            "Jend naa kompoos": 'engrais',
            "Semences de mil": 'semences',
            "Insecticide pour les tomates": 'phytosanitaire',
            "Salaire des ouvriers": 'main_oeuvre',
            "Main d'œuvre récolte": 'main_oeuvre',
            "Carburant du tracteur": 'carburant_transport',
            "Paiement du transporteur": 'carburant_transport',
            "Réparation de la pompe": 'irrigation',
            "Tuyaux goutte à goutte": 'irrigation',
            "Sacs d'emballage": 'stockage',
            "Achat d'une houe": 'materiel',
            # travaux agricoles
            "Préparation du sol, labour motorisé et confection des planches": 'main_oeuvre',
            "Sarclage et binage": 'main_oeuvre',
            "Plantation et tuteurage": 'main_oeuvre',
        }
        for label, expected in cases.items():
            with self.subTest(label=label):
                self.assertEqual(infer_expense_category(label), expected)

    def test_unknown_or_empty_label_is_other_never_guessed(self):
        for label in ("", None, "Cadeau", "Loyer du mois", "Divers"):
            with self.subTest(label=label):
                self.assertEqual(infer_expense_category(label), 'autre')

    def test_work_stems_do_not_swallow_other_categories(self):
        """Garde-fous : « récolte » ou « moisson » ne doivent pas capter l'emballage ni le matériel."""
        self.assertEqual(infer_expense_category("Emballage pour la récolte"), 'stockage')
        self.assertEqual(infer_expense_category("Location d'une moissonneuse"), 'materiel')
        self.assertEqual(infer_expense_category("Carburant pour le labour"), 'carburant_transport')
        self.assertEqual(infer_expense_category("Achat de semences pour la plantation"), 'semences')

    def test_activity_type_takes_precedence_over_its_description(self):
        from apps.finances.categories import infer_activity_category
        self.assertEqual(infer_activity_category("Plantation et Tuteurage", "Mise en terre des plants de tomate"), 'main_oeuvre')
        self.assertEqual(infer_activity_category("Activité", "Achat d'engrais"), 'engrais')  # type muet : la description décide
        self.assertEqual(infer_activity_category("", ""), 'autre')

    def test_stem_must_start_a_word(self):
        self.assertEqual(infer_expense_category("Configuree"), 'autre')

    def test_every_code_has_a_label(self):
        for code in CATEGORY_CODES:
            self.assertTrue(category_label(code))
        self.assertEqual(category_label('inconnue'), category_label('autre'))


class TransactionCategoryTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='cat1', phone='+221770300001', password='Motdepasse#2026')
        self.other = User.objects.create_user(username='cat2', phone='+221770300002', password='Motdepasse#2026')
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        today = datetime.date.today()
        self.crop = Crop.objects.create(
            user=self.user, name='Mil', crop_type='Céréale', planting_date=today, expected_harvest_date=today,
            area_size=1.0, location='Thiès')

    def test_expense_is_classified_on_save(self):
        tx = Transaction.objects.create(user=self.user, transaction_type='expense', amount=1000,
                                        description="Achat d'engrais", date=datetime.date.today())
        self.assertEqual(tx.category, 'engrais')

    def test_explicit_category_is_kept(self):
        tx = Transaction.objects.create(user=self.user, transaction_type='expense', amount=1000,
                                        description="Achat d'engrais", category='materiel', date=datetime.date.today())
        self.assertEqual(tx.category, 'materiel')

    def test_income_has_no_category(self):
        tx = Transaction.objects.create(user=self.user, transaction_type='income', amount=1000,
                                        description="Vente de mil", date=datetime.date.today())
        self.assertEqual(tx.category, '')

    def test_save_with_update_fields_still_persists_the_inferred_category(self):
        tx = Transaction.objects.create(user=self.user, transaction_type='expense', amount=1, description="x",
                                        category='materiel', date=datetime.date.today())
        Transaction.objects.filter(pk=tx.pk).update(category='')
        tx.refresh_from_db()
        tx.description = "Insecticide"
        tx.save(update_fields=['description'])
        tx.refresh_from_db()
        self.assertEqual(tx.category, 'phytosanitaire')

    def test_activity_cost_creates_a_classified_expense_linked_to_its_crop(self):
        Activity.objects.create(crop=self.crop, activity_type='Fertilisation', description='NPK',
                                date=datetime.date.today(), cost=15000)
        tx = Transaction.objects.get(activity__crop=self.crop)
        self.assertEqual(tx.category, 'engrais')
        self.assertEqual(tx.crop, self.crop)

    def test_api_exposes_category_and_label(self):
        response = self.client.post('/api/finances/transactions/', {
            'transaction_type': 'expense', 'amount': '2500', 'date': '2026-10-20', 'description': 'Carburant motopompe',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        self.assertEqual(response.data['category'], 'carburant_transport')
        self.assertTrue(response.data['category_label'])

    def test_api_rejects_unknown_category(self):
        response = self.client.post('/api/finances/transactions/', {
            'transaction_type': 'expense', 'amount': '10', 'date': '2026-10-20', 'description': 'x', 'category': 'pirate',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_api_refuses_a_crop_of_another_user(self):
        foreign = Crop.objects.create(
            user=self.other, name='Riz', crop_type='Céréale', planting_date=datetime.date.today(),
            expected_harvest_date=datetime.date.today(), area_size=1.0, location='Saint-Louis')
        response = self.client.post('/api/finances/transactions/', {
            'transaction_type': 'expense', 'amount': '10', 'date': '2026-10-20', 'description': 'x', 'crop': str(foreign.id),
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(Transaction.objects.filter(crop=foreign).exists())

    def test_api_income_drops_any_category(self):
        response = self.client.post('/api/finances/transactions/', {
            'transaction_type': 'income', 'amount': '10', 'date': '2026-10-20', 'description': 'x', 'category': 'engrais',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['category'], '')


class ReclassifyOtherMigrationTests(TestCase):
    def test_only_rows_still_in_other_are_reevaluated(self):
        import importlib
        from django.apps import apps as django_apps
        migration = importlib.import_module('apps.finances.migrations.0008_reclassify_other_expenses')
        user = User.objects.create_user(username='rc1', phone='+221770900001', password='Motdepasse#2026')
        today = datetime.date.today()
        labour = Transaction.objects.create(user=user, transaction_type='expense', amount=30000, date=today,
                                            description="Préparation du sol et labour", category='autre')
        unknown = Transaction.objects.create(user=user, transaction_type='expense', amount=1, date=today,
                                             description="Cadeau", category='autre')
        chosen = Transaction.objects.create(user=user, transaction_type='expense', amount=1, date=today,
                                            description="Sarclage", category='materiel')
        income = Transaction.objects.create(user=user, transaction_type='income', amount=1, date=today, description="Labour")

        migration.reclassify_other(django_apps, None)

        for tx in (labour, unknown, chosen, income):
            tx.refresh_from_db()
        self.assertEqual(labour.category, 'main_oeuvre')
        self.assertEqual(unknown.category, 'autre')      # la règle ne trouve rien : inchangé
        self.assertEqual(chosen.category, 'materiel')    # catégorie déjà choisie : jamais modifiée
        self.assertEqual(income.category, '')            # un revenu n'a pas de catégorie
