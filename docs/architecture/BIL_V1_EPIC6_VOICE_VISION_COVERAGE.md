# BIL v1 Epic 6 — Voice and meal-image gateway closure

Current release scope only; historical TODO files are not authority.

| Area | Closure evidence |
|---|---|
| Device voice recognition | `MealVoiceInputService` uses the operating-system recognizer, an explicit requested locale, bounded listening, live transcript review, cancellation, and honest unavailable/error states. |
| Voice-to-food flow | The reviewed transcript enters trusted catalog search; it never creates nutrition values and does not save without the existing meal confirmation flow. |
| Image capture | Camera/gallery capture remains user initiated and constrained to supported image formats and 12 MB. |
| Authenticated gateway | `MealImageAnalysisService` requires HTTPS and a signed Supabase session before upload. The Edge Function validates that session before forwarding. |
| Provider boundary | The provider URL and secret remain server-only. Requests time out and failures close without local inference. |
| Strict result schema | Up to eight visible-food names, confidence, and visual evidence only. Malformed or oversized responses are rejected as a whole. |
| Nutrition safety | Image analysis never supplies calories or nutrients. A candidate must separately match a trusted food record and the user must confirm it. |
| Privacy | No image bytes are persisted by this flow. The gateway does not log the request body and returns only constrained candidates. |
| Offline behavior | Voice availability depends on the device recognizer. Image analysis clearly fails unavailable offline; manual search and installed catalog packs remain usable. |
| Platform declarations | Android camera/microphone and speech-recognition visibility; iOS camera/photo/microphone/speech usage descriptions. |

Externally blocked release evidence: production vision-provider URL/secret configuration, Edge Function deployment, and physical-device camera/microphone permission validation. These are deployment/device operations, not mock fallbacks.
