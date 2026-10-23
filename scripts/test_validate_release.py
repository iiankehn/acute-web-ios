import copy
from pathlib import Path
import plistlib
import tempfile
import unittest

from validate_release import EXPECTED_REASONS, validate_bundle, validate_command_log, validate_manifest


def manifest():
    return {
        "NSPrivacyTracking": False,
        "NSPrivacyTrackingDomains": [],
        "NSPrivacyCollectedDataTypes": [],
        "NSPrivacyAccessedAPITypes": [
            {"NSPrivacyAccessedAPIType": category, "NSPrivacyAccessedAPITypeReasons": sorted(reasons)}
            for category, reasons in EXPECTED_REASONS.items()
        ],
    }


class ReleaseValidationTests(unittest.TestCase):
    def test_duplicate_keyboard_registration_fails(self):
        validate_command_log("Metadata extraction skipped. No AppIntents.framework dependency found.")
        with self.assertRaises(ValueError):
            validate_command_log("Keyboard Shortcut (duplicate modifierFlags: command, input: ,):")

    def test_state_published_during_view_update_fails(self):
        with self.assertRaises(ValueError):
            validate_command_log("<unknown>:0: warning: -[AcuteWebUITests testUnsupportedTypedAddressShowsClearFeedback] : "
                                 "Publishing changes from within view updates is not allowed, this will cause undefined behavior.")

    def test_current_manifest_passes(self):
        validate_manifest(manifest())

    def test_missing_timestamp_declaration_fails(self):
        value = manifest()
        value["NSPrivacyAccessedAPITypes"].pop()
        with self.assertRaises(ValueError):
            validate_manifest(value)

    def test_tracking_or_collection_requires_review(self):
        for key, value in [("NSPrivacyTracking", True),
                           ("NSPrivacyCollectedDataTypes", [{}]),
                           ("NSPrivacyTrackingDomains", ["example.com"])]:
            changed = manifest()
            changed[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_manifest(changed)

    def test_duplicate_category_or_wrong_reason_fails(self):
        value = manifest()
        duplicate = copy.deepcopy(value)
        duplicate["NSPrivacyAccessedAPITypes"].append(duplicate["NSPrivacyAccessedAPITypes"][0])
        value["NSPrivacyAccessedAPITypes"][0]["NSPrivacyAccessedAPITypeReasons"] = ["INVALID"]
        for changed in [duplicate, value]:
            with self.assertRaises(ValueError):
                validate_manifest(changed)

    def test_bundle_policy_permissions_ats_and_debug_checks(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory)
            (app / "PrivacyInfo.xcprivacy").write_bytes(plistlib.dumps(manifest()))
            (app / "PRIVACY.md").write_text("Retention and deletion; GitHub Issues", encoding="utf-8")
            info = {"CFBundleExecutable": "AcuteWeb", "CFBundleVersion": "1",
                    "CFBundleShortVersionString": "0.5.0",
                    "NSCameraUsageDescription": "Website camera access",
                    "NSMicrophoneUsageDescription": "Website microphone access",
                    "ITSAppUsesNonExemptEncryption": False,
                    "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": True}}
            (app / "Info.plist").write_bytes(plistlib.dumps(info))
            (app / "AcuteWeb").write_bytes(b"release executable fixture")
            validate_bundle(app, release=True)
            (app / "AcuteWeb").write_bytes(b"-acuteUITestPageError")
            with self.assertRaises(ValueError):
                validate_bundle(app, release=True)
            validate_bundle(app, release=False)
            for key, value in [("ITSAppUsesNonExemptEncryption", True), ("UIApplicationSceneManifest", {})]:
                changed = dict(info, **{key: value})
                (app / "Info.plist").write_bytes(plistlib.dumps(changed))
                with self.subTest(key=key), self.assertRaises(ValueError):
                    validate_bundle(app)
            info["NSAppTransportSecurity"] = {"NSAllowsArbitraryLoads": True}
            (app / "Info.plist").write_bytes(plistlib.dumps(info))
            with self.assertRaises(ValueError):
                validate_bundle(app)
            del info["NSAppTransportSecurity"]
            del info["NSCameraUsageDescription"]
            (app / "Info.plist").write_bytes(plistlib.dumps(info))
            with self.assertRaises(ValueError):
                validate_bundle(app)
            (app / "PRIVACY.md").unlink()
            with self.assertRaises(OSError):
                validate_bundle(app)


if __name__ == "__main__":
    unittest.main()
