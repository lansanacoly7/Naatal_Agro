"""Analyse des échéances en langage naturel (horloge figée : jeudi 22/10/2026 à 14h00)."""
import datetime

from django.test import SimpleTestCase
from django.utils import timezone

from apps.ai_assistant.scheduling import parse_schedule, strip_time_expressions

NOW = timezone.make_aware(datetime.datetime(2026, 10, 22, 14, 0))  # un jeudi


def at(day, hour, minute=0):
    return timezone.make_aware(datetime.datetime(2026, 10, day, hour, minute))


class ParseScheduleTests(SimpleTestCase):
    def check(self, text, expected, defaulted=False):
        result = parse_schedule(text, NOW)
        self.assertIsNotNone(result, text)
        self.assertEqual(result.when, expected, text)
        self.assertEqual(result.time_defaulted, defaulted, text)

    def test_explicit_day_and_time(self):
        self.check("demain à 7h", at(23, 7))
        self.check("demain à 7h30", at(23, 7, 30))
        self.check("demain à 19:30", at(23, 19, 30))
        self.check("ce soir à 7h", at(22, 19))
        self.check("après-demain à 6h", at(24, 6))
        self.check("lundi à 6h", at(26, 6))

    def test_evening_marker_resolves_12_24_ambiguity(self):
        self.check("demain 7 h du soir", at(23, 19))
        self.check("vendredi à 3h de l'après-midi", at(23, 15))

    def test_day_without_time_is_flagged_as_defaulted(self):
        self.check("demain matin", at(23, 8), defaulted=True)
        self.check("demain", at(23, 8), defaulted=True)
        self.check("après-demain soir", at(24, 18), defaulted=True)
        self.check("vendredi après-midi", at(23, 15), defaulted=True)
        self.check("ce soir", at(22, 18), defaulted=True)

    def test_same_weekday_means_next_week(self):
        self.check("jeudi", at(29, 8), defaulted=True)

    def test_time_alone_is_the_next_occurrence(self):
        self.check("à 16h", at(22, 16))
        self.check("à 7h", at(23, 7))  # 7h est déjà passée aujourd'hui

    def test_relative_durations_are_exact(self):
        self.check("dans 2 heures", at(22, 16))
        self.check("dans 30 min", at(22, 14, 30))
        self.check("dans 3 jours", at(25, 14))

    def test_wolof_markers(self):
        self.check("ëllëk ci suba", at(23, 8), defaulted=True)
        self.check("ëllëk ci ngoon", at(23, 18), defaulted=True)

    def test_text_without_schedule_returns_none(self):
        for text in ("arroser les piments", "10 sacs de mil sur 2 hectares", "", "25 kg de riz à 12000 FCFA"):
            with self.subTest(text=text):
                self.assertIsNone(parse_schedule(text, NOW))

    def test_invalid_clock_values_are_ignored(self):
        self.assertIsNone(parse_schedule("à 27h", NOW))
        self.assertIsNone(parse_schedule("à 7h75", NOW))

    def test_past_time_today_stays_in_the_past(self):
        """« aujourd'hui à 13h » alors qu'il est 14h : l'assistant doit pouvoir le refuser, pas le décaler."""
        result = parse_schedule("aujourd'hui à 13h", NOW)
        self.assertLess(result.when, NOW)


class StripTimeExpressionsTests(SimpleTestCase):
    def test_removes_only_the_schedule(self):
        cases = {
            "arroser les oignons demain matin": "arroser les oignons",
            "arroser les piments demain à 7h": "arroser les piments",
            "traiter les chenilles ce soir à 19h": "traiter les chenilles",
            "payer l'ouvrier lundi à 6h30": "payer l'ouvrier",
            "vérifier l'irrigation dans 2 heures": "vérifier l'irrigation",
            "semer le mil après-demain": "semer le mil",
            "arroser ëllëk ci suba": "arroser",
        }
        for text, expected in cases.items():
            with self.subTest(text=text):
                self.assertEqual(strip_time_expressions(text), expected)

    def test_text_without_schedule_is_unchanged(self):
        self.assertEqual(strip_time_expressions("vérifier les 2 pompes"), "vérifier les 2 pompes")
