# BIL v1 Epic 10 — Health and device closure

## Release truth

- Health Connect and HealthKit expose the same fitness/wellness read contract:
  steps, distance, active energy, workouts, sleep, weight, body fat, lean mass,
  heart rate, resting heart rate, HRV, hydration, energy and selected nutrient
  values. Clinical categories remain excluded. Health Connect can export
  reviewed weight and nutrition; HealthKit exports reviewed weight only, with
  write access requested separately from reading.
- Both native bridges use a bounded 365-day initial window when authorized.
  Health Connect requests its separate history grant only on provider versions
  that support it and falls back to the platform's ordinary 30-day window when
  that grant is unavailable or declined.
- Imported records retain provider, source/device, record identity, UTC time,
  original time-zone identifier, canonical unit and confidence.
- Native record IDs and BLE sample IDs are deduplicated locally. Manual records
  remain distinct; measured records never silently overwrite manual entries.
- Sync is local-first. Anchors, tombstones, seen IDs and the last safe snapshot
  persist locally. An offline/native failure preserves the last safe snapshot.
- Android can revoke Health Connect permissions in-app. Apple requires the user
  to revoke HealthKit access in Settings, and BIL reports that honestly.
- BLE accepts only supported SIG health profiles, known units, plausible values,
  non-future/non-stale timestamps and unique sample IDs. Missing battery data is
  displayed as unknown, never invented.
- Removing a BLE device disconnects it and clears BIL session state. Android may
  still require system Bluetooth settings to remove the OS bond.

## Compatibility and external gates

The executable matrix is `BilDeviceCompatibilityMatrix`. Native bridges and
automated mocks are implemented, but no entry is labeled physically tested.
Before public enablement, test on a real supported Android phone with Health
Connect, a real iPhone with HealthKit, and representative certified BLE devices
for every advertised profile. Record OS, provider version, device model,
firmware, permission revoke/regrant, offline recovery and duplicate handling.

## Privacy

Health payloads are not written to logs or notifications. Permission is
explicit, cloud upload is not implied, and unavailable hardware produces an
unavailable/error state instead of simulated measurements.
