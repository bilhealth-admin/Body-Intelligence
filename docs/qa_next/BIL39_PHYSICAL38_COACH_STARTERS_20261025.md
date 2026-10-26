# Physical iPhone baseline: Build 38 versus the BIL39 candidate

This is an actual owner-device session on 25 October 2026. USB/DVT captured
original screenshots; CoreDevice HID delivered taps and contact drags. Opening
the app, Sources, scrolling, returning to the same conversation and focusing
the composer were confirmed by separately inspected screenshots. The installed
application was Build 38. No signed Build 39 device result is claimed here.

## Four starter buttons: actual Build 38 results

| Button | Observed result | Requirement |
| --- | --- | --- |
| Check nutrition | Automatically opened My Plan with “Action not completed”. Returning showed a workout/meal-plan response rather than nutrition analysis. | BIL-03, BIL-09 |
| Review my day | Initially showed the existing preparing status, then automatically opened Today. Back returned to Dashboard. Reopening Coach showed a navigation acknowledgement rather than the requested review. | BIL-06; additional navigation reproduction |
| Explain sleep | Asked “How much … did you have?”, inserting the recorded-sleep question as a food name. | BIL-07 |
| Next best focus | Asserted that there were no saved goals/recent logs, although the opening brief displayed recent weigh-ins and Goals displayed a saved target. This proves a visible contradiction; it does not establish the server payload's contents. | BIL-04 |

The last response's action opened Goals without a visible Back control or main
navigation. A real left-edge drag did not return. Restarting the application
escaped the page. No goal or health entry was edited. This reproduces BIL-05.
More → View profile loaded successfully in one attempt with its avatar; that
does not disprove the reported intermittent profile-loading defect.

The four test conversations were kept in local conversation history. Original
screenshots contain personal data and remain in the private local evidence
directory; they are not repository assets or public reviewer images.

## Additional defects discovered in the integrated BIL39 source

1. `CoachActionPresentationPolicy` used substring matching. The navigation
   marker `view` matched `review`, so a review could replace a useful answer
   with navigation copy and leave the conversation. A new test failed on the
   exact starter text before the fix. English navigation now requires an
   explicit command, and Latin markers use word boundaries. Existing direct
   Arabic/English requests and confirmation-gated protections remain tested.
2. `IntelligenceCenterEngine` treated every sleep question as a general sleep
   duration question, bypassing personal context. The real starter widget tests
   failed for both languages before this fix. General duration questions still
   use the existing local guidance; recorded sleep/trend requests now use the
   consented context path. No prompt, model or cloud deployment was changed.

## Executed candidate checks

`physical38-four-starter-widget-and-policy-v2.jsonl` completed successfully:
**62 test results passed, zero failed/error results**. This is local evidence
for the uncommitted integration tree, not final-SHA release certification.

The eight actual starter-widget cases tap each chip in Arabic and English,
exercise the actual page/intent/engine path, verify exactly one model-gateway
invocation with the supplied goal, weight and nutrition context, retain the
answer in the Coach route despite a model navigation proposal, and read SQLite
to verify no weight, meal or water record was created. The gateway is a
recording fixture, not a real Gemini call. Other checks cover the exact eight
starter prompts' food/plan exclusion, navigation policy, general sleep answers,
context behavior, speech and the existing locale matrix.

Raw local logs and hashed screenshots are indexed by the private central
register's `ios38-physical-baseline-20261025.json`. Remaining Build 38 requests
and signed Build 39 parity must retain separate explicit results. No untested
item is marked passed and no TestFlight upload was performed by this session.
