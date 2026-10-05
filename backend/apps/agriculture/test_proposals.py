import json
from io import StringIO

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import SimpleTestCase, TestCase
from django.urls import reverse

from apps.agriculture.guides_loader import load_guides
from apps.agriculture.knowledge_review import ProposalError, approve_proposal, is_trusted_url, reject_proposal
from apps.agriculture.models import AgronomicGuide, KnowledgeProposal

User = get_user_model()

GOOD_URL = 'https://agriculture.gouv.sn/wp-content/uploads/2024/01/guide-test.pdf'


class TrustedUrlTests(SimpleTestCase):
    def test_accepts_listed_domains_and_their_subdomains_in_https(self):
        for url in ('https://agriculture.gouv.sn/x.pdf', 'https://agritrop.cirad.fr/1/doc.pdf',
                    'https://www.fao.org/3/y1263f/y1263f00.pdf', 'https://FAO.org/page'):
            with self.subTest(url=url):
                self.assertTrue(is_trusted_url(url))

    def test_rejects_http_unknown_and_lookalike_domains(self):
        for url in ('http://agriculture.gouv.sn/x.pdf', 'https://example.com/fao.org', 'https://notfao.org/x',
                    'https://fao.org.evil.com/x', 'https://evil.com/?u=https://fao.org', 'ftp://fao.org/x',
                    '', 'pas une url'):
            with self.subTest(url=url):
                self.assertFalse(is_trusted_url(url))


class ProposalFlowTests(TestCase):
    def setUp(self):
        self.reviewer = User.objects.create_user(username='relecteur', password='x', is_staff=True)
        self.guide = AgronomicGuide.objects.get(slug='mil')

    def make(self, **overrides):
        data = dict(
            guide=self.guide, field='harvest', proposed_text="Récolter quand l'épi est sec.",
            quote="Les épis sont récoltés à maturité complète, lorsque le grain est dur.",
            source_title='Guide test', source_publisher='Ministère', source_year='2024', source_url=GOOD_URL,
        )
        data.update(overrides)
        return KnowledgeProposal.objects.create(**data)

    def test_approval_appends_text_with_a_new_source_marker(self):
        before = len(self.guide.sources)
        proposal = self.make()
        approve_proposal(proposal, self.reviewer, 'vérifié')

        self.guide.refresh_from_db()
        proposal.refresh_from_db()
        self.assertEqual(self.guide.harvest, f"Récolter quand l'épi est sec. [{before + 1}]")
        self.assertEqual(self.guide.sources[-1]['url'], GOOD_URL)
        self.assertTrue(self.guide.locally_edited)
        self.assertEqual((proposal.status, proposal.reviewed_by, proposal.review_note), ('approved', self.reviewer, 'vérifié'))
        self.assertIsNotNone(proposal.reviewed_at)

    def test_second_proposal_from_same_source_reuses_its_number(self):
        approve_proposal(self.make(), self.reviewer)
        sources_after_first = len(AgronomicGuide.objects.get(slug='mil').sources)
        approve_proposal(self.make(field='yield_info', proposed_text='Environ 1 t/ha.'), self.reviewer)
        guide = AgronomicGuide.objects.get(slug='mil')
        self.assertEqual(len(guide.sources), sources_after_first)
        self.assertTrue(guide.yield_info.endswith(f'[{sources_after_first}]'))

    def test_text_is_added_after_existing_content(self):
        existing = self.guide.fertilization
        approve_proposal(self.make(field='fertilization', proposed_text='Fumier : 5 t/ha.'), self.reviewer)
        self.guide.refresh_from_db()
        self.assertTrue(self.guide.fertilization.startswith(existing))
        self.assertIn('\nFumier : 5 t/ha. [', self.guide.fertilization)

    def test_pest_proposal_adds_a_structured_entry(self):
        approve_proposal(self.make(field='pests_diseases', pest_name='Chenille des chandelles',
                                   proposed_text='Surveiller dès la montaison.'), self.reviewer)
        self.guide.refresh_from_db()
        names = [p['name'] for p in self.guide.pests_diseases]
        self.assertIn('Chenille des chandelles', names)

    def test_pest_proposal_requires_a_name(self):
        proposal = self.make(field='pests_diseases', pest_name='')
        with self.assertRaises(ProposalError):
            approve_proposal(proposal, self.reviewer)

    def test_untrusted_source_cannot_be_approved_and_changes_nothing(self):
        proposal = self.make(source_url='https://blog-anonyme.example.com/mil')
        snapshot = AgronomicGuide.objects.get(slug='mil').harvest
        with self.assertRaises(ProposalError):
            approve_proposal(proposal, self.reviewer)
        self.guide.refresh_from_db()
        proposal.refresh_from_db()
        self.assertEqual(self.guide.harvest, snapshot)
        self.assertEqual(proposal.status, 'pending')
        self.assertFalse(self.guide.locally_edited)

    def test_quote_is_mandatory(self):
        with self.assertRaises(ProposalError):
            approve_proposal(self.make(quote='   '), self.reviewer)

    def test_a_proposal_is_processed_only_once(self):
        proposal = self.make()
        approve_proposal(proposal, self.reviewer)
        with self.assertRaises(ProposalError):
            approve_proposal(proposal, self.reviewer)
        with self.assertRaises(ProposalError):
            reject_proposal(proposal, self.reviewer)

    def test_rejection_leaves_the_guide_untouched(self):
        proposal = self.make()
        snapshot = AgronomicGuide.objects.get(slug='mil').harvest
        reject_proposal(proposal, self.reviewer, 'source ancienne')
        self.guide.refresh_from_db()
        proposal.refresh_from_db()
        self.assertEqual(self.guide.harvest, snapshot)
        self.assertEqual((proposal.status, proposal.review_note), ('rejected', 'source ancienne'))


class ProposalAdminTests(TestCase):
    def setUp(self):
        self.admin_user = User.objects.create_superuser(username='admin', email='a@b.sn', password='x')
        self.client.force_login(self.admin_user)
        self.guide = AgronomicGuide.objects.get(slug='mil')
        self.url = reverse('admin:agriculture_knowledgeproposal_changelist')

    def make(self, **overrides):
        data = dict(guide=self.guide, field='harvest', proposed_text='Texte validé.', quote='extrait',
                    source_title='Guide', source_publisher='Ministère', source_url=GOOD_URL)
        data.update(overrides)
        return KnowledgeProposal.objects.create(**data)

    def test_approve_action_updates_the_guide(self):
        proposal = self.make()
        response = self.client.post(self.url, {'action': 'approve_selected', '_selected_action': [str(proposal.pk)]}, follow=True)
        self.assertEqual(response.status_code, 200)
        proposal.refresh_from_db()
        self.assertEqual(proposal.status, 'approved')
        self.assertEqual(proposal.reviewed_by, self.admin_user)
        self.guide.refresh_from_db()
        self.assertIn('Texte validé.', self.guide.harvest)

    def test_approve_action_refuses_untrusted_sources(self):
        proposal = self.make(source_url='https://inconnu.example.org/page')
        response = self.client.post(self.url, {'action': 'approve_selected', '_selected_action': [str(proposal.pk)]}, follow=True)
        proposal.refresh_from_db()
        self.assertEqual(proposal.status, 'pending')
        self.assertContains(response, 'domaines de confiance')

    def test_reject_action(self):
        proposal = self.make()
        self.client.post(self.url, {'action': 'reject_selected', '_selected_action': [str(proposal.pk)]}, follow=True)
        proposal.refresh_from_db()
        self.assertEqual(proposal.status, 'rejected')


class LoaderProtectionTests(TestCase):
    def test_edited_guide_survives_a_reload_but_not_a_forced_one(self):
        guide = AgronomicGuide.objects.get(slug='mil')
        guide.summary = 'Résumé validé par un relecteur.'
        guide.locally_edited = True
        guide.save()

        out = StringIO()
        call_command('load_agronomic_guides', stdout=out)
        guide.refresh_from_db()
        self.assertEqual(guide.summary, 'Résumé validé par un relecteur.')
        self.assertIn('conservée(s)', out.getvalue())

        call_command('load_agronomic_guides', '--force', stdout=StringIO())
        guide.refresh_from_db()
        self.assertNotEqual(guide.summary, 'Résumé validé par un relecteur.')

    def test_unedited_guides_are_refreshed(self):
        AgronomicGuide.objects.filter(slug='oignon').update(summary='ancien texte')
        processed, skipped = load_guides(AgronomicGuide)
        self.assertEqual(AgronomicGuide.objects.get(slug='oignon').summary.startswith('ancien'), False)
        self.assertEqual(skipped, 0)
        self.assertGreaterEqual(processed, 5)

    def test_admin_edit_marks_the_guide_as_locally_edited(self):
        admin_user = User.objects.create_superuser(username='boss', email='b@c.sn', password='x')
        self.client.force_login(admin_user)
        guide = AgronomicGuide.objects.get(slug='oignon')
        self.assertFalse(guide.locally_edited)
        url = reverse('admin:agriculture_agronomicguide_change', args=[guide.pk])
        data = {f: getattr(guide, f) for f in ('slug', 'name', 'scientific_name', 'category', 'summary', 'zones',
                                               'calendar', 'soil_and_sowing', 'water_needs', 'fertilization',
                                               'harvest', 'yield_info', 'limitations')}
        data.update({'cycle_days_min': 70, 'cycle_days_max': 120, 'pests_diseases': '[]', 'sources': json.dumps(guide.sources),
                     'aliases': '[]', 'summary': 'Modifié en administration.'})
        response = self.client.post(url, data)
        errors = response.context['adminform'].form.errors if response.status_code == 200 else None
        self.assertEqual(response.status_code, 302, f'formulaire invalide : {errors}')
        guide.refresh_from_db()
        self.assertEqual(guide.summary, 'Modifié en administration.')
        self.assertTrue(guide.locally_edited)
