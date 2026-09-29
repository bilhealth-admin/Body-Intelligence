# Sapphire QA diagnosis — not acceptance

The exact untouched baseline 59839c7deb4d1cc860275b9e69578e299cc24d0a was
executed with all the formerly excluded/partially-selected files in run
36631944086. Artifact 11063175900 preserves 272 failed visible cases (271 pixel
comparisons and one UTF-8 prefix decoder error), 201 passed cases, and five
pre-existing skipped cases. No reference images, assertions or application
sources were changed in that baseline experiment.

The headless helper requested lowercase roboto-regular.ttf and
materialicons-regular.otf. On case-sensitive Linux it could fall back to
Montserrat Bold and omit MaterialIcons. The SDK names are Roboto-Regular.ttf,
Roboto-Medium.ttf, Roboto-Bold.ttf and MaterialIcons-Regular.otf. The correction
loads these same original SDK faces, removes silent alternate-font fallback,
and retains all existing golden images and their strict pixel comparator.
This is a test-environment correction, not a production font replacement.

The architecture guard tried to decode exactly 160 bytes as UTF-8; its cutoff
could split a valid Arabic code point. ASCII generation-marker detection now
uses a byte-preserving prefix decode. Full source decoding and every existing
size ceiling remain unchanged.

In candidate 6dfe3f9c1644cab27c95ccff1f2f617664ffd5b1, analysis passed and 284
focused cases passed; two Community cases failed (Polish label overflow at
1.6 scale and dark surface/canvas mismatch). This follow-up fixes those actual
layout/theme conditions. It does not remove or weaken their expectations.

The two release manifests are reopened as drafts. Only a green exact-source
full suite plus reviewed Community visual matrix can close source acceptance.
All native/device/store acceptance remains separately unclaimed.
