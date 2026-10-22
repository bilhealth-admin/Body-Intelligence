"""Xcode 26.6 architecture-aware Simulator entitlements: strict regressions."""
import plistlib
import unittest
from bil_ios_simulator_adhoc_sign import (
    resolve_simulated_entitlements_path,
    verify_simulated_sections,
)

class SimulatedXcentLog(unittest.TestCase):
    def test_empty_export_in_unrelated_target_before_runner_is_ignored(self):
        target="/tmp/DerivedData/Runner.build/Runner.app-Simulated.xcent"
        log="export LD_ENTITLEMENTS_SECTION=\nexport LD_ENTITLEMENTS_SECTION\\="+target+"\n"
        self.assertEqual(str(resolve_simulated_entitlements_path({},log)),target)

    def test_empty_only_remains_failure(self):
        with self.assertRaises(ValueError):
            resolve_simulated_entitlements_path({}, "export LD_ENTITLEMENTS_SECTION=\n")

    def test_two_different_paths_remain_failure(self):
        with self.assertRaises(ValueError):
            resolve_simulated_entitlements_path({}, (
                "export LD_ENTITLEMENTS_SECTION=/tmp/A/Runner.app-Simulated.xcent\n"
                "export LD_ENTITLEMENTS_SECTION=/tmp/B/Runner.app-Simulated.xcent\n"))

class SimulatedOtoolRegressions(unittest.TestCase):
    def setUp(self):
        self.expected = {
            "application-identifier": "43F9Y5Y96K.com.bilhealth.bodyintelligencelog",
            "com.apple.developer.healthkit": True,
        }
        data=plistlib.dumps(self.expected, fmt=plistlib.FMT_XML)
        self.plist=data+b"\0"*((-len(data))%4)

    def section(self,arch,mode,blob=None):
        data=self.plist if blob is None else blob
        lines=[f"Runner (architecture {arch}):",
               "Contents of (__TEXT,__entitlements) section"]
        for offset in range(0,len(data),16):
            part=data[offset:offset+16]
            if mode=="bytes":
                value=" ".join(f"{b:02x}" for b in part)
            elif mode=="le32":
                self.assertEqual(len(part)%4,0)
                value=" ".join(part[i:i+4][::-1].hex() for i in range(0,len(part),4))
            else:
                self.fail("unrecognized fixture mode")
            lines.append(f"{4096+offset:016x}  {value}")
        return "\n".join(lines)

    def test_both_actual_xcode26_architecture_formats_pass(self):
        raw=(self.section("x86_64","bytes")+"\n"+self.section("arm64","le32")+"\n").encode()
        self.assertEqual(verify_simulated_sections(raw,self.expected,2),2)

    def test_legacy_contiguous_hex_fixture_passes(self):
        lines=["Contents of (__TEXT,__entitlements) section"]
        lines.extend(f"{4096+i:016x} {self.plist[i:i+16].hex()}"
                     for i in range(0,len(self.plist),16))
        self.assertEqual(verify_simulated_sections("\n".join(lines).encode(),self.expected,1),1)

    def test_legacy_one_long_hex_row_passes(self):
        raw=("Contents of (__TEXT,__entitlements) section\n"
             "0000000100003000 "+self.plist.hex()+"\n").encode()
        self.assertEqual(verify_simulated_sections(raw,self.expected,1),1)

    def test_missing_architecture_is_rejected(self):
        with self.assertRaises(ValueError):
            verify_simulated_sections(self.section("arm64","le32").encode(),self.expected,2)

    def test_different_simulated_entitlements_is_rejected(self):
        wrong=plistlib.dumps({"different":True},fmt=plistlib.FMT_XML)
        wrong+=b"\0"*((-len(wrong))%4)
        raw=(self.section("x86_64","bytes")+"\n"
             +self.section("arm64","le32",wrong)).encode()
        with self.assertRaises(ValueError):
            verify_simulated_sections(raw,self.expected,2)

    def test_malformed_otool_tokens_are_rejected(self):
        with self.assertRaises(ValueError):
            verify_simulated_sections(
                b"Contents of (__TEXT,__entitlements) section\n0000000100003000 abcd12\n",
                self.expected,1)

if __name__=="__main__":
    unittest.main(verbosity=2)
