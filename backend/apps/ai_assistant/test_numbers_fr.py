"""Lecture des nombres dits ou écrits en français (chiffres, « 15 mille », mots)."""
from django.test import SimpleTestCase

from apps.ai_assistant.numbers_fr import parse_amount, words_to_number


class ParseAmountTests(SimpleTestCase):
    def test_digits(self):
        cases = {"15000": 15000.0, "15 000 FCFA": 15000.0, "15.000": 15000.0, "15,000": 15000.0, "2,5": 2.5,
                 "J'ai payé 12500 francs": 12500.0, "20 sacs": 20.0, "0,5 kg": 0.5}
        for text, expected in cases.items():
            with self.subTest(text=text):
                self.assertEqual(parse_amount(text), expected)

    def test_digits_with_a_multiplier(self):
        cases = {"15 mille": 15000.0, "15 mille francs": 15000.0, "2 millions": 2_000_000.0, "25k": 25000.0, "1,5 million": 1_500_000.0}
        for text, expected in cases.items():
            with self.subTest(text=text):
                self.assertEqual(parse_amount(text), expected)

    def test_words(self):
        cases = {
            "quinze mille": 15000.0, "vingt cinq mille": 25000.0, "vingt-cinq mille cinq cents": 25500.0,
            "deux millions": 2_000_000.0, "cent": 100.0, "cent vingt": 120.0, "deux cent cinquante": 250.0,
            "quatre-vingt-dix": 90.0, "quatre vingts": 80.0, "soixante dix": 70.0, "mille": 1000.0,
            "trois mille deux cents": 3200.0, "dix": 10.0, "vingt et un": 21.0, "mille deux cent trente quatre": 1234.0,
            "Quinze Mille FCFA": 15000.0,
        }
        for text, expected in cases.items():
            with self.subTest(text=text):
                self.assertEqual(parse_amount(text), expected)

    def test_the_largest_number_wins_over_an_incidental_word(self):
        self.assertEqual(parse_amount("un peu plus de dix mille"), 10000.0)
        self.assertEqual(words_to_number("une partie, environ cinquante sacs"), 50.0)

    def test_digits_take_precedence_over_words(self):
        self.assertEqual(parse_amount("20 sacs, vingt-cinq mille au total"), 20.0)

    def test_no_number(self):
        for text in ("", "bonjour", "je ne sais pas", "du mil", "zéro", "0", None):
            with self.subTest(text=text):
                self.assertIsNone(parse_amount(text))

    def test_accents_and_case_do_not_matter(self):
        self.assertEqual(parse_amount("QUATRE-VINGT-DIX mille"), 90000.0)
        self.assertEqual(parse_amount("Vingt-Cinq"), 25.0)
