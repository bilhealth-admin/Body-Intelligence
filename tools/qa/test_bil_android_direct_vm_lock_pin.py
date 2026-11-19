"""Exercise the real source-lock guards without launching native tooling."""
import ast
import hashlib
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / ".github/scripts/bil_android_direct_vm_attach.py"
APPROVED_LOCK_SHA256 = "fb3df7a93ef5d14b2ac8f394012ed749f3138b05570926c483a3e9071de1dad7"
GUARD_CODES = {
    "EXACT_SOURCE_AND_PUB_LOCK_REQUIRED",
    "SOURCE_PUB_LOCK_CHANGED_DURING_COMMAND",
    "SOURCE_PUB_LOCK_CHANGED_DURING_BUILD",
    "SOURCE_PUB_LOCK_CHANGED_DURING_DRIVER",
}


class ExactAndroidSourceLockTests(unittest.TestCase):
    def setUp(self):
        tree = ast.parse(HELPER.read_text(encoding="utf-8"))
        pins = [node for node in tree.body if isinstance(node, ast.Assign)
                and any(isinstance(target, ast.Name) and target.id == "PUB_LOCK" for target in node.targets)]
        self.assertEqual(len(pins), 1)
        self.pin = ast.literal_eval(pins[0].value)
        self.assertEqual(self.pin, APPROVED_LOCK_SHA256)
        self.lock = (ROOT / "pubspec.lock").read_bytes()
        self.assertEqual(hashlib.sha256(self.lock).hexdigest(), APPROVED_LOCK_SHA256)
        self.guards = {}
        for node in ast.walk(tree):
            if (isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "need"
                    and len(node.args) == 2 and isinstance(node.args[1], ast.Constant)
                    and node.args[1].value in GUARD_CODES):
                code = node.args[1].value
                self.assertNotIn(code, self.guards)
                self.guards[code] = compile(ast.Expression(body=node), str(HELPER), "eval")
        self.assertEqual(set(self.guards), GUARD_CODES)
        # Compile the helper's actual predicate/need body, not a rewritten gate.
        need = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "need")
        namespace = {}
        exec(compile(ast.Module(body=[need], type_ignores=[]), str(HELPER), "exec"), namespace)
        self.need = namespace["need"]
        self.temporary = tempfile.TemporaryDirectory(prefix="bil-native-lock-pure-")
        self.addCleanup(self.temporary.cleanup)
        self.fixture_root = Path(self.temporary.name)
        self.fixture_lock = self.fixture_root / "pubspec.lock"
        self.fixture_lock.write_bytes(self.lock)

    def execute(self, code, *, head="a" * 40):
        return eval(self.guards[code], {
            "need": self.need, "root": self.fixture_root, "PUB_LOCK": self.pin,
            "hashlib": hashlib, "head": head,
            "os": SimpleNamespace(environ={"GITHUB_SHA": "a" * 40}),
        })

    def test_all_four_real_guards_accept_the_exact_approved_lock(self):
        for code in sorted(GUARD_CODES):
            with self.subTest(guard=code):
                self.execute(code)

    def test_all_four_real_guards_reject_changed_lock_bytes(self):
        self.fixture_lock.write_bytes(self.lock + b"\n# unreviewed raw-lock change\n")
        for code in sorted(GUARD_CODES):
            with self.subTest(guard=code), self.assertRaisesRegex(ValueError, "^" + code + "$"):
                self.execute(code)

    def test_correct_lock_does_not_waive_exact_source_head(self):
        with self.assertRaisesRegex(ValueError, "^EXACT_SOURCE_AND_PUB_LOCK_REQUIRED$"):
            self.execute("EXACT_SOURCE_AND_PUB_LOCK_REQUIRED", head="b" * 40)

    def test_missing_lock_is_not_accepted(self):
        self.fixture_lock.unlink()
        for code in sorted(GUARD_CODES):
            with self.subTest(guard=code), self.assertRaises(FileNotFoundError):
                self.execute(code)


if __name__ == "__main__":
    unittest.main()
