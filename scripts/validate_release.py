"""Scoped release checks, not an App Review approval or a complete API audit."""
import argparse
from pathlib import Path
import plistlib


EXPECTED_REASONS = {
    "NSPrivacyAccessedAPICategoryUserDefaults": {"CA92.1"},
    "NSPrivacyAccessedAPICategoryFileTimestamp": {"C617.1"},
}
DEBUG_MARKERS = (
    b"acute-ui-fixture", b"-acuteUITestHistoryPage",
    b"-acuteUITestRenderedPage", b"-acuteUITestPageError",
)


def validate_manifest(manifest):
    if manifest.get("NSPrivacyTracking") is not False:
        raise ValueError("Tracking must be explicitly disabled")
    for key in ("NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes"):
        if manifest.get(key) != []:
            raise ValueError(f"{key} must remain an explicit empty array; review any data-practice change")
    entries = manifest.get("NSPrivacyAccessedAPITypes", [])
    actual = {}
    for entry in entries:
        category = entry.get("NSPrivacyAccessedAPIType")
        reasons = entry.get("NSPrivacyAccessedAPITypeReasons", [])
        if category in actual or not reasons:
            raise ValueError("Duplicate category or missing required reason")
        actual[category] = set(reasons)
    if actual != EXPECTED_REASONS:
        raise ValueError("Required-reason API declarations differ from the audited app usage")


def validate_bundle(app, release=False):
    with (app / "PrivacyInfo.xcprivacy").open("rb") as stream:
        validate_manifest(plistlib.load(stream))
    policy = (app / "PRIVACY.md").read_text(encoding="utf-8")
    if "Retention and deletion" not in policy or "GitHub Issues" not in policy:
        raise ValueError("Bundled privacy policy is missing retention/deletion or contact information")
    with (app / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    for key in ("NSCameraUsageDescription", "NSMicrophoneUsageDescription",
                "CFBundleShortVersionString", "CFBundleVersion"):
        if not isinstance(info.get(key), str) or not info[key].strip():
            raise ValueError(f"Missing {key}")
    if info.get("ITSAppUsesNonExemptEncryption") is not False:
        raise ValueError("Export-compliance answer ITSAppUsesNonExemptEncryption must be declared false")
    scenes = info.get("UIApplicationSceneManifest", {})
    if scenes.get("UIApplicationSupportsMultipleScenes") is not True:
        raise ValueError("iPad multiple-window support must stay declared")
    # No network-security exception has been reviewed for this beta.
    if info.get("NSAppTransportSecurity"):
        raise ValueError("Unreviewed App Transport Security configuration")
    if release:
        executable = info.get("CFBundleExecutable", "")
        if not executable or Path(executable).name != executable:
            raise ValueError("Invalid executable name")
        binary = (app / executable).read_bytes()
        if any(marker in binary for marker in DEBUG_MARKERS):
            raise ValueError("Debug-only browser fixtures found in Release binary")


def validate_command_log(log):
    if "Keyboard Shortcut (duplicate modifierFlags:" in log:
        raise ValueError("Duplicate keyboard shortcuts reported by UIKit menu registration")
    if "Publishing changes from within view updates is not allowed" in log:
        raise ValueError("SwiftUI reported a state change published during a view update")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--command-log", type=Path, action="append", default=[])
    args = parser.parse_args()
    try:
        validate_bundle(args.app, args.release)
        for path in args.command_log:
            validate_command_log(path.read_text(encoding="utf-8", errors="replace"))
    except (OSError, ValueError, TypeError, KeyError) as error:
        parser.exit(1, f"Release validation failed: {error}\n")
    print("Scoped privacy, policy, permission and release-fixture checks passed.")
