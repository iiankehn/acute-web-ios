---
name: acute-ios-release
description: Prepare and publish an Acute Web iOS sideload pre-release — MARKETING_VERSION bump, RELEASE-NOTES.md, readiness gate, and the tag or manual Build run that publishes the unsigned IPA. Use when asked to release, version or ship Acute Web on iOS/iPadOS.
---

# Release Acute Web for iOS

Releases are GitHub pre-releases containing `AcuteWeb-unsigned.ipa`,
`SHA256SUMS.txt` and `build.json`. Users sign and sideload them themselves.

## 1. Prepare on a branch

1. Set `MARKETING_VERSION` in `project.yml` (for example `0.6.0`). Leave
   `CURRENT_PROJECT_VERSION`; CI sets the build number to the workflow run number.
2. Update `RELEASE-NOTES.md`: it is the release body and ships inside the
   artifact. Keep the sideloading instructions, free-account limits and the
   "only iOS 27 is tested" caveat. Update version numbers in the install steps.
3. Update the version section of `README.md` and the status in
   `docs/BETA-READINESS.md`. Claim only evidence that exists: CI is not device
   validation and not App Review approval.
4. Open a PR; all simulator jobs and the IPA job must pass.

## 2. Publish (confirm with the user first)

After the PR merges, either:

- run the **Build** workflow manually on `main` (it creates tag `v` + `MARKETING_VERSION`), or
- push tag `vX.Y.Z` that matches `MARKETING_VERSION` exactly.

The `release` job runs only after every test and IPA job passes.

## 3. Verify

- The pre-release titled "Acute Web X.Y.Z beta" has all three files.
- `SHA256SUMS.txt` matches the IPA and `build.json` names the merged commit.

## 4. Afterwards

Follow `../brain/playbooks/ship-a-release.md` (CORE Dev article and so on), then
update the iOS column in `../brain/projects/acute-web.md`.
