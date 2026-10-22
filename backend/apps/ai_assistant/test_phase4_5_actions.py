import datetime
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from apps.finances.models import Transaction, Sale
from apps.inventory.models import StockItem
from apps.ai_assistant.models import AIConversation, AIInteraction
from apps.ai_assistant.actions import detect_action_intent, execute_action

User = get_user_model()


class Phase4And5ActionsTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='+221770009999',
            phone='+221770009999',
            password='Password123#',
            first_name='Modou'
        )
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def test_detect_action_intent_expense(self):
        """Vérifie la détection d'intention d'enregistrement de dépense."""
        intent = detect_action_intent("J'ai dépensé 15 000 FCFA pour l'achat d'engrais urée")
        self.assertTrue(intent['has_intent'])
        self.assertEqual(intent['action_type'], 'record_expense')
        self.assertEqual(intent['params']['amount'], 15000.0)
        self.assertIn("engrais", intent['params']['description'].lower())

    def test_detect_action_intent_sale(self):
        """Vérifie la détection d'intention d'enregistrement de vente."""
        intent = detect_action_intent("J'ai vendu 25 sacs de riz à 12000 FCFA")
        self.assertTrue(intent['has_intent'])
        self.assertEqual(intent['action_type'], 'record_sale')
        self.assertEqual(intent['params']['quantity'], 25.0)
        self.assertEqual(intent['params']['price_per_unit'], 12000.0)
        self.assertEqual(intent['params']['product_name'], 'Riz')

    def test_two_step_expense_confirmation_cycle(self):
        """
        Cycle obligatoire en 2 temps :
        1. Demande d'action -> proposition d'action (pas d'écriture en BDD).
        2. Confirmation par 'Oui' -> exécution effective et certification en BDD.
        """
        conv = AIConversation.objects.create(user=self.user, title="Comptabilité")

        # Étape 1 : Demande
        res1 = self.client.post('/api/ai/ask/', {
            'query': "J'ai dépensé 25000 FCFA pour du compost biologique",
            'conversation_id': str(conv.id)
        }, format='json')

        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res1.data['action_data']['status'], 'pending_confirmation')
        self.assertIn("25 000 FCFA", res1.data['response'])
        self.assertIn("Oui, valider", res1.data['suggestions'])

        # Vérifier qu'AUCUNE transaction n'a encore été écrite en base
        self.assertEqual(Transaction.objects.filter(user=self.user, amount=25000.0).count(), 0)

        # Étape 2 : Confirmation explicite
        res2 = self.client.post('/api/ai/ask/', {
            'query': "Oui, confirme",
            'conversation_id': str(conv.id)
        }, format='json')

        self.assertEqual(res2.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res2.data['action_data']['status'], 'executed')
        self.assertIn("confirmée et enregistrée", res2.data['response'])

        # Vérifier que la transaction existe RÉELLEMENT en base désormais
        tx = Transaction.objects.filter(user=self.user, amount=25000.0).first()
        self.assertIsNotNone(tx)
        self.assertEqual(tx.transaction_type, 'expense')
        self.assertIn("compost", tx.description.lower())

    def test_two_step_expense_cancellation_cycle(self):
        """Vérifie que l'annulation n'écrit rien en base."""
        conv = AIConversation.objects.create(user=self.user, title="Comptabilité")

        # Demande
        self.client.post('/api/ai/ask/', {
            'query': "Dépensé 8000 FCFA pour du carburant",
            'conversation_id': str(conv.id)
        }, format='json')

        # Annulation
        res = self.client.post('/api/ai/ask/', {
            'query': "Non, annule",
            'conversation_id': str(conv.id)
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['action_data']['status'], 'cancelled')
        self.assertIn("annulée", res.data['response'])
        self.assertEqual(Transaction.objects.filter(user=self.user, amount=8000.0).count(), 0)

    def test_button_confirmation_endpoint(self):
        """Le bouton « Confirmer » de l'interface confirme une proposition existante par son identifiant."""
        StockItem.objects.create(user=self.user, name='Tomate Roma', quantity=50.0, unit='caisses')

        proposal = self.client.post('/api/ai/ask/', {
            'query': "J'ai vendu 10 caisses de Tomate Roma à 5000 FCFA",
        }, format='json')
        self.assertEqual(proposal.data['action_data']['status'], 'pending_confirmation')
        # Une proposition n'écrit rien
        self.assertEqual(Sale.objects.filter(user=self.user).count(), 0)

        response = self.client.post('/api/ai/actions/execute/', {
            'interaction_id': proposal.data['id'],
            'decision': 'confirm',
        }, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['action_data']['status'], 'executed')
        self.assertEqual(response.data['action_data']['result']['data']['total_revenue'], 50000.0)

        # Le stock a été décrémenté (50 - 10 = 40) et la recette enregistrée
        stock = StockItem.objects.get(user=self.user, name='Tomate Roma')
        self.assertEqual(stock.quantity, 40.0)
        tx = Transaction.objects.filter(user=self.user, transaction_type='income').first()
        self.assertIsNotNone(tx)
        self.assertEqual(float(tx.amount), 50000.0)

        # Vérifier la transaction de revenu
        tx = Transaction.objects.filter(user=self.user, transaction_type='income').first()
        self.assertIsNotNone(tx)
        self.assertEqual(float(tx.amount), 50000.0)

    def test_analytics_deterministic_endpoint(self):
        """Vérifie le reporting déterministe certifié de l'IA (Phase 4)."""
        # Créer une dépense et un stock
        Transaction.objects.create(
            user=self.user,
            transaction_type='expense',
            amount=10000.0,
            description='Graines',
            date=datetime.date.today()
        )
        StockItem.objects.create(
            user=self.user,
            name='Maïs doux',
            quantity=3.0,  # En alerte car <= 5
            unit='sacs'
        )

        response = self.client.get('/api/ai/analytics/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        finances = response.data['finances']
        self.assertEqual(finances['total_expenses_fcfa'], 10000.0)
        self.assertEqual(finances['balance_fcfa'], -10000.0)
        self.assertFalse(finances['is_profitable'])

        inventory = response.data['inventory']
        self.assertEqual(inventory['total_items'], 1)
        self.assertEqual(inventory['low_stock_count'], 1)
        self.assertEqual(inventory['low_stock_items'][0]['name'], 'Maïs doux')

    def test_detect_action_intent_expense_with_quantity_bugfix(self):
        """
        Vérifie la correction du bogue critique d'extraction :
        Dans 'J'ai acheté 3 sacs d'engrais à 15000 FCFA', le montant DOIT être 15000 et non 3.
        """
        intent = detect_action_intent("J'ai acheté 3 sacs d'engrais à 15000 FCFA")
        self.assertTrue(intent['has_intent'])
        self.assertEqual(intent['action_type'], 'record_expense')
        self.assertEqual(intent['params']['amount'], 15000.0)
        self.assertIn("3 sacs", intent['params']['description'])
        self.assertIn("engrais", intent['params']['description'].lower())

        # Test achat avec 'pour'
        intent2 = detect_action_intent("Acheté 2 sacs de semences pour 20000 FCFA")
        self.assertTrue(intent2['has_intent'])
        self.assertEqual(intent2['params']['amount'], 20000.0)

        # Test wolof
        intent_wo = detect_action_intent("Jend naa 3 saag kompoos ci 15000 cfa")
        self.assertTrue(intent_wo['has_intent'])
        self.assertEqual(intent_wo['params']['amount'], 15000.0)

    def test_detect_action_intent_sale_with_total_price(self):
        """
        Vérifie la détection d'une vente avec montant global :
        'J'ai vendu 50 kg de maïs pour 25000 FCFA' -> total = 25000, price_per_unit = 500.
        """
        intent = detect_action_intent("J'ai vendu 50 kg de maïs pour 25000 FCFA")
        self.assertTrue(intent['has_intent'])
        self.assertEqual(intent['action_type'], 'record_sale')
        self.assertEqual(intent['params']['quantity'], 50.0)
        self.assertEqual(intent['params']['price_per_unit'], 500.0)
        self.assertEqual(intent['params']['product_name'], 'Maïs')

    def test_analytics_periodic_filtering(self):
        """Vérifie le filtrage périodique certifié de l'analyse financière (Phase 4)."""
        today = datetime.date.today()
        # Transaction du mois en cours
        Transaction.objects.create(
            user=self.user,
            transaction_type='expense',
            amount=5000.0,
            description='Carburant aujourd hui',
            date=today
        )
        # Transaction passée (il y a 60 jours)
        past_date = today - datetime.timedelta(days=60)
        Transaction.objects.create(
            user=self.user,
            transaction_type='expense',
            amount=40000.0,
            description='Ancien tracteur',
            date=past_date
        )

        # 1. Requête globale (period='all')
        res_all = self.client.get('/api/ai/analytics/?period=all')
        self.assertEqual(res_all.status_code, status.HTTP_200_OK)
        # Total dépense = 5000 + 40000 = 45000
        self.assertEqual(res_all.data['finances']['total_expenses_fcfa'], 45000.0)

        # 2. Requête filtrée mois en cours (period='current_month')
        res_month = self.client.get('/api/ai/analytics/?period=current_month')
        self.assertEqual(res_month.status_code, status.HTTP_200_OK)
        self.assertEqual(res_month.data['finances']['period'], 'current_month')
        # Dépense du mois courant = 5000.0 uniquement (l'ancienne de 40000 est exclue)
        self.assertEqual(res_month.data['finances']['total_expenses_fcfa'], 5000.0)

