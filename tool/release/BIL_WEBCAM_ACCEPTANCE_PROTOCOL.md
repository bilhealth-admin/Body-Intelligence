# BIL webcam/emulator acceptance protocol

Recovered into version control: 2026-09-10

This manual device tool is NOT RUN in the code-only audit. Its canonical path is
`tool/release/run_bil_webcam_acceptance.ps1`. Every device mode requires explicit
`-AllowDeviceExecution`. Runtime evidence is never inferred from a code test.

This is the final live-device gate. Run it only after the non-camera release
matrix is closed. It intentionally does not claim that an emulated scene is a
host webcam.

## Preparation

1. Close the Android emulator after the current non-camera checks finish.
2. Run `run_bil_webcam_acceptance.ps1 -Mode Inspect` and confirm that the
   Android emulator reports `webcam0`.
3. Run `run_bil_webcam_acceptance.ps1 -Mode Configure`.
4. Cold-start `BIL_Pixel_7_API_35`. Do not use Quick Boot from a snapshot that
   predates the camera configuration.
5. Open BIL and confirm that Camera permission is granted and the live preview
   visibly follows the laptop webcam.
6. Run `run_bil_webcam_acceptance.ps1 -Mode Run`.

The runner records a screenshot and one CSV row for every case. The required
31-case set is fixed: 10 clear foods, 5 difficult food views, 5 non-food
objects, 5 known food barcodes, 3 non-food barcodes, and 3 cache-miss barcodes.

## Required evidence per request

Each CSV row records `camera_input_source`, recognized item, food/non-food
classification, barcode result, cache hit, Gemini fallback, actual model,
input/output tokens, latency, cost, success/failure, quota consumption,
deduplication, notes, and screenshot path. Values for model/tokens/cost must be
copied from server telemetry; they must not be estimated from UI output.

## Pass rule

The runner prints `REAL_CAMERA_ACCEPTANCE=PASS` only when all 31 rows exist and
all are marked `PASS`. Any missing telemetry or incorrect quota/dedup behavior
is a failure, not a documentation exception.

The CSV and `webcam-*` screenshots are written under
`artifacts/runtime_evidence/`. The original AVD configuration is preserved as
`config.ini.pre-webcam.bak` before the first change.

After evidence capture, `run_bil_webcam_acceptance.ps1 -Mode Restore` restores
the original AVD camera configuration. Restore mode is not part of the pass
count and must be run only after the emulator is closed.
