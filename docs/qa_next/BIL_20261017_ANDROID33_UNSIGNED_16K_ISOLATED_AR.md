# BIL07 — Android33 unsigned native AAB isolated inspection

The older iOS36/Android33 build created a signed AAB but failed a 16 KB verifier. A prior QA patch repaired only the checker's missing Python sys import, without changing alignment, GNU_RELRO, or Bundletool checks.

This branch builds an unsigned Flutter 3.44.6 Android versionCode 33 QA release AAB with no store signing key and no store upload. It downloads pinned Bundletool 1.18.3, checks its SHA256 and inspects every shared library through the fail-closed checker. Only diagnostic text is archived, never the app binary.

Passing is proof for the candidate binary built in this ephemeral runner; it does not establish that the old signed Android 33 package or any actual physical 16 KB Android device passes installation.
