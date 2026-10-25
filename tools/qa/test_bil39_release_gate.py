"""Only the fail-closed QA receipt logic is tested; fake receipts are NOT app QA."""
import copy
import unittest
import bil39_release_gate as qa


def sample():
    sha = "a" * 40
    receipt = {"status": "PASS", "source_sha": sha, "url": "https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/999", "unexpected_skips": 0}
    prs = {}
    for n in qa.WORKERS:
        head = f"{n:040x}"
        run = {"conclusion": "success", "head_sha": head, "url": "https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/999"}
        prs[str(n)] = {"head_sha": head, "base_sha": qa.BASE, "state": "open",
                       "draft": True, "changed_files": [f"test/mock_{n}.dart"],
                       "verify": copy.deepcopy(run), "android_debug": copy.deepcopy(run)}
    return {"schema": "bil39.strict.qa.snapshot.v1", "base_sha": qa.BASE,
            "candidate": {"sha": sha, "human_reviewed": True}, "prs": prs,
            "reviewed_overlap_resolutions": {},
            "coverage": {case: {"status": "FIXED_VERIFIED", "source_sha": sha,
                     "url": "https://github.com/bilhealth-admin/Body-Intelligence/issues/999"}
                     for case in qa.CASES},
            "gates": {k: copy.deepcopy(receipt) for k in qa.GATES},
            "native_matrix": {"android": {v: copy.deepcopy(receipt) for v in qa.ANDROID},
                              "ios": {v: copy.deepcopy(receipt) for v in qa.IOS}},
            "safety_flags": {f: False for f in qa.SAFE_FLAGS},
            "ios_build_number": 39}


class FailClosedEvidenceTests(unittest.TestCase):
    def test_synthetic_full_contract_is_passable(self):
        self.assertEqual(qa.evaluate(sample())["decision"], "READY_FOR_INTERNAL_TESTFLIGHT_UPLOAD_ONLY")

    def test_no_candidate_blocks(self):
        s = sample(); s["candidate"] = None
        self.assertEqual(qa.evaluate(s)["decision"], "BLOCKED")

    def test_failed_worker_does_not_inherit_android_success(self):
        s = sample(); s["prs"]["17"]["verify"]["conclusion"] = "failure"
        self.assertEqual(qa.evaluate(s)["decision"], "BLOCKED")

    def test_unexpected_skip_blocks(self):
        s = sample(); s["gates"]["FULL_EIGHT_SHARDS"]["unexpected_skips"] = 1
        self.assertEqual(qa.evaluate(s)["decision"], "BLOCKED")

    def test_mismatched_sha_blocks(self):
        s = sample(); s["gates"]["SECURITY"]["source_sha"] = "b" * 40
        self.assertEqual(qa.evaluate(s)["decision"], "BLOCKED")

    def test_overlapping_pr_paths_block(self):
        s = sample(); path = ".github/workflows/verify.yml"
        s["prs"]["18"]["changed_files"].append(path)
        s["prs"]["19"]["changed_files"].append(path)
        r = qa.evaluate(s)
        self.assertEqual(r["decision"], "BLOCKED")
        self.assertEqual(r["conflicting_paths"][path], [18, 19])

    def test_protected_payment_cta_blocks(self):
        s = sample(); s["prs"]["18"]["changed_files"].append("lib/commerce/store-purchase-cta.dart")
        self.assertEqual(qa.evaluate(s)["decision"], "BLOCKED")

    def test_missing_safety_flag_blocks(self):
        s = sample(); del s["safety_flags"]["mutated_ios38"]
        self.assertEqual(qa.evaluate(s)["decision"], "BLOCKED")

    def test_missing_coach_acceptance_blocks(self):
        s = sample(); s["coverage"]["QA-COACH-18"]["status"] = "UNVERIFIED"
        self.assertEqual(qa.evaluate(s)["decision"], "BLOCKED")

    def test_invalid_snapshot_never_passes(self):
        s = sample(); s["schema"] = "bogus"
        self.assertEqual(qa.evaluate(s)["decision"], "INVALID_SNAPSHOT")


if __name__ == "__main__":
    unittest.main()
