"""Garde-fous des scripts destructifs : refus en production, confirmation obligatoire, restauration sécurisée."""
import io
import shutil
import subprocess
import tempfile
from pathlib import Path
from unittest import skipUnless

from django.test import SimpleTestCase, override_settings

from core.safety import UnsafeOperation, require_safe_to_erase

REPO = Path(__file__).resolve().parents[2]


class Tty(io.StringIO):
    def isatty(self):
        return True


class RequireSafeToEraseTests(SimpleTestCase):
    @override_settings(DEBUG=False)
    def test_refuses_in_production_even_with_yes(self):
        with self.assertRaises(UnsafeOperation) as raised:
            require_safe_to_erase("test", assume_yes=True)
        self.assertTrue(str(raised.exception.code).startswith("ERREUR"))  # message affiché, sortie non nulle
        self.assertIn("pas un environnement de développement", str(raised.exception))

    @override_settings(DEBUG=True)
    def test_yes_flag_allows_development(self):
        require_safe_to_erase("test", assume_yes=True)

    @override_settings(DEBUG=True)
    def test_no_terminal_and_no_flag_refuses(self):
        with self.assertRaises(UnsafeOperation) as raised:
            require_safe_to_erase("test", stream=io.StringIO())
        self.assertIn("--yes", str(raised.exception))

    @override_settings(DEBUG=True)
    def test_typed_confirmation(self):
        require_safe_to_erase("test", stream=Tty(), ask=lambda prompt: "oui")
        for answer in ("", "non", "ouiii?", "yes"):
            with self.subTest(answer=answer), self.assertRaises(UnsafeOperation):
                require_safe_to_erase("test", stream=Tty(), ask=lambda prompt, a=answer: a)


def _real_bash():
    """Un vrai bash (pas le lanceur WSL de System32, qui ne sait pas exécuter ces scripts)."""
    path = shutil.which('bash')
    return path if path and 'system32' not in path.lower() else None


@skipUnless(_real_bash(), "bash indisponible")
class RestoreScriptTests(SimpleTestCase):
    def test_restore_without_terminal_or_flag_changes_nothing(self):
        with tempfile.TemporaryDirectory() as folder:
            backup = Path(folder) / 'naatal_agro_sqlite_test.db.gz'
            backup.write_bytes(b'not a real backup')
            result = subprocess.run([_real_bash(), str(REPO / 'scripts' / 'restore_db.sh'), str(backup)],
                                    stdin=subprocess.DEVNULL, capture_output=True, encoding='utf-8', errors='replace', cwd=REPO, timeout=30)
        self.assertEqual(result.returncode, 2)
        self.assertIn("aucun terminal", result.stdout)
        self.assertNotIn("Restauration depuis", result.stdout)
