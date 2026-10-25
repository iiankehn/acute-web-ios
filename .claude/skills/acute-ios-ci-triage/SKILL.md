---
name: acute-ios-ci-triage
description: Diagnose and fix a failing Acute Web iOS Build workflow (simulator unit/UI tests, iPad, iPhone Duo, accessibility audits, privacy manifest validation, IPA packaging). Use when CI is red on acute-web-ios or a test fails only on GitHub runners.
---

# Triage a failing iOS Build run

Swift cannot run in the cloud container, so the logs are the only evidence.
Diagnose from them fully before pushing; every round trip is long.

## 1. Collect evidence

- Get the failing job's log (GitHub MCP `get_job_logs`, or the Actions UI).
  Note the job (`simulator`, `ipad-smoke`, `iphone-duo`, `device-ipa`,
  `release`) and the first failing step.
- Search the log for `error:`, `** BUILD FAILED **`, `** TEST FAILED **`,
  `XCTAssert`, `Test Case '-[` ... `failed`, and `validate_release` messages.
- Result bundles (`*.xcresult`) are uploaded as artifacts if more detail is needed.

## 2. Classify

| Symptom | Likely cause | Action |
|---|---|---|
| Compile error | Code | Fix; check every platform-conditional (`#if`, `@available`) path |
| Times out before any test runs | Cold simulator runtime (~10 min) | Raise only the job `timeout-minutes` |
| Website or download test hangs after earlier tests | Leftover WebKit processes | Keep or add a simulator restart; see `../brain/learnings/ci.md` |
| Accessibility audit failure | Real contrast, label, size or clipping issue | Fix the view; only near-pass contrast warnings are logged instead of failing |
| Duplicate keyboard shortcut | Two commands register the same key | Remove one registration |
| `validate_release.py` error | Privacy manifest, missing reason or debug marker in Release | Fix the manifest or code, update `EXPECTED_REASONS` only for a real reviewed API use |
| Tag does not match `MARKETING_VERSION` | Release job | Fix `project.yml` or the tag |

Tests are never retried and unit tests must pass twice. "Flaky" means a test
depends on timing or state: make it deterministic (wait on a real condition,
reset state, launch the app per test) rather than lengthening waits.

## 3. Fix and verify

- Smallest fix for the root cause. Never weaken assertions, skip or disable
  tests, or add retries.
- Run `python3 -m unittest discover -s scripts -p 'test_*.py'` if scripts changed.
- Re-read the diff for Swift compile risks before pushing.
- If the lesson is new, add it to `../brain/learnings/ci.md`.
