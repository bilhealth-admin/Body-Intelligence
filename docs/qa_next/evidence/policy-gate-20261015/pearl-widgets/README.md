# Pearl UI evidence

Actual Flutter Widget renders of the production goal editor and speech disclosure, using BilFlagshipTheme and existing BilFrostedPanel. These are not signed-app/device or reviewer-account screenshots. Arabic uses the project Noto Naskh font through the evidence loader; English uses SDK Roboto, so no iOS system-font claim. No production typography/colors changed.

The four route journeys tested real SQLite save/reopen, loading/paid/Free transitions, and keyboard reachability. The four speech visual cases include AR/EN at320x640 with200% text in dark mode and visible semantic actions. The first four-case visual run failed only because a fixture SemanticsHandle was disposed too late; fixed in finally and rerun4/4 PASS. Original failed log retained.

Copy/Plans/product Goldens20/20 PASS without update. No baseline was changed. Existing60 failure PNG files were copied and hash-recorded before these runs; none is staged as an approved baseline.

Independent read-only visual review of all8 images found no P0/P1 clipping or contrast defect. P2: scroll affordance is subtle at200% in the short-height disclosure; content remains scrollable and decision actions visible. The evidence font loader is not proof of the exact iOS/Android system Arabic font. These observations do not substitute for owner approval of the appearance or imply app-wide polish completion.
