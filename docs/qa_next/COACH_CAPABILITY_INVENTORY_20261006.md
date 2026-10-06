# AI Coach capability inventory — 2026-10-06

**Status: historical source audit and implementation plan, not functional or visual closure.**

Implementation update: the nine health/meal/memory command boundaries described below were subsequently replaced with atomic journals, authoritative readback and version-checked Undo. See [the native command checkpoint](NATIVE_COMMANDS_COMMUNITY_CHECKPOINT_20261006_AR.md) and its exact evidence; unimplemented capability families in this inventory remain open.

Audited repository: `bilhealth-admin/Body-Intelligence`, authorized branch
`qa/coach-community-next-20261005`, HEAD
`f1e7e09e88e639fc3417d1e7ce822e0906e32e4a` plus the current QA working tree.
The remote branch was read again before creating this document and matched that
HEAD. The inspected Coach working-tree changes were localization, the distinct
permission tooltip, and extraction of its unchanged menu into
`intelligence_coach_menu.dart`.

This inventory covers every current `BilToolRegistry` descriptor, every
`IntelligenceActionType`, the navigation allow-list, the 31 capability families
in the handoff gap map, and additional owner-required surfaces omitted from that
older map. It does not claim that every feature in the repository has a Coach
adapter, or that a route proves execution of the feature behind it. The handoff's
older `planned_adapter` labels are historical; the current source below is the
authority for what is now wired.

No app or test changes were made for this inventory. No model/provider calls,
Production operations, builds, dependency changes, or billing changes were made.
R5 verification and the four portable regression shards have their own evidence;
this document cannot mark them green.

## 1. What currently executes

There are **23 tool descriptors, 24 action enum values, and 11 named navigation
targets**. Eleven descriptors perform local data/settings/memory mutations, two
read local context, nine hand off to routes, and one signs out through the
existing auth flow. These are source classifications, not a claim of complete
end-to-end test coverage.

The central sources are [the tool registry][tools], [action types][types],
[the native action handler][flow], [permission policy][permission], and
[the navigation registry][navigation]. Every execution branch in the following
table is in `_IntelligenceActionFlow._executeAction` in `intelligence_action_flow.dart`.

Policy abbreviations: **RO** = read-only; **Low** = low-risk; **Write** = reversible
write; **Sensitive** = sensitive; **Destructive** = destructive.
Boundaries: **Nav** = client navigation; **Local** = trusted local repository;
**Server** = the descriptor's server-verified classification. The latter does
not mean that opening a route executed a server transaction.

### Complete descriptor and handler matrix

| Registered tool | Action type; policy | Arguments | Actual effect / API | Receipt and Undo state |
|---|---|---|---|---|
| `navigate` | `navigate`; Low / Nav | Required `target` from the 11-target allow-list | `BilNavigationRegistry.resolve` → `_openCoachRoute(path)` | Route handoff; no health-data commit receipt. |
| `read_nutrition_remaining` | `readNutritionRemaining`; RO / Local | None | Reads `coachContextSnapshotProvider.future`; calls `nutritionRemainingFor(DateTime.now())` | Text from the context snapshot; unavailable remaining data throws. No mutation or Undo. |
| `read_profile_identity` | `readProfileIdentity`; RO / Local | None | Reads `coachContextSnapshotProvider.future.minimalIdentity` | Name / missing-name text; no mutation or Undo. |
| `open_weight_log` | `navigate`; Low / Nav | None | Registry inserts `target: weight_history`; opens `/weight-history` | Route only. |
| `open_meals` | `reviewMeal`; Low / Nav | None | Opens `/daily-log?focus=meal` | Route only; no food selection, quantity review, or food commit. |
| `open_meals_yesterday` | `reviewMeal`; Low / Nav | None | Registry inserts `dayOffset: -1`; sets `selectedLogDateProvider`; opens `/daily-log?focus=meal` | Changes UI date selection; no meal write. |
| `open_workouts` | `reviewWorkout`; Low / Nav | None | Pushes `/wellness/workouts/log` | Route only; no exercise record. |
| `open_plan` | `openPlan`; Low / Nav | None | Opens `/plan?origin=dashboard` | Route only; no plan activation or editing. |
| `open_report` | `openReport`; Low / Nav | None | Opens `/analytics` | Route only; no generated or exported report. |
| `manage_subscription` | `manageSubscription`; Sensitive / Server | None | Pushes `/plans` after confirmation | Handoff only; does not cancel, purchase, or restore. Keep existing commerce policy unchanged. |
| `set_theme_mode` | `setThemeMode`; Low / Local | Required `mode`: `dark`, `light`, `system` | `AppSettingsController.setThemeMode` awaits settings storage and then updates provider state | Receipt uses requested value; Undo writes the captured previous mode. No revision comparison or receipt readback. |
| `set_language` | `setLanguage`; Low / Local | Required `locale`, canonicalized by `BilLocalePolicy` | `AppSettingsController.setLocale` commits local settings and queues existing display-locale sync | Receipt uses requested canonical locale; Undo writes prior locale. No revision comparison or receipt readback. |
| `update_goal` | `updateGoal`; Write / Local | Required finite `targetWeightKg` 20–500; optional canonical `targetDate` | One Drift transaction reads profile, active goal, and latest weight; calls `UserProfileRepository.save` and `GoalRepository.save`; failed goal save rolls back profile | Reads **before** state and checks positive goal ID. Retires the durable proposal. Receipt is still payload-derived. Undo restores captured profile/goal in a transaction without checking for subsequent edits. |
| `save_measurements` | `saveMeasurements`; Write / Local | At least one of `neckCm`, `waistCm`, `hipsCm`, `chestCm`, `armCm`, `thighCm`, each finite 20–300; optional canonical `date` | `BodyMeasurementRepository.getForDay` → `saveForDay(preserveExistingValues: true)` | Partial write preserves omitted measurements. Receipt lists supplied fields, not saved readback. Undo restores the prior day snapshot or deletes that day; no expected revision. |
| `quick_add_macros` | `quickAddMacros`; Write / Local | Required `mealType` and all four numeric macros; optional canonical `date`; calories ≤10000, each macro ≤2000, nonnegative and not all zero | `MealRepository.addQuickMacroEntry` creates one synthetic Quick Add food/item within a transaction; may reuse an existing day/meal bucket | Returns **meal ID**, not inserted item ID. Receipt incorrectly assumes that meal did not previously exist. Undo calls `deleteMealCascade(mealId)`, which can remove unrelated older items in that bucket. All four fields are forced known. |
| `update_meal_item` | `updateMealItem`; Write / Local | Positive `itemId`; finite `quantityGrams` >0 and ≤100000 | `getMealItem` → `updateMealItem(id, quantity)` | Recalculates quantity/macros from the current food row and increments revision. Receipt uses requested quantity. Undo writes old quantity without expected revision or immutable nutrition-basis enforcement. |
| `delete_meal_item` | `deleteMealItem`; Sensitive / Local | Positive `itemId` | `getMealItem` → `deleteMealItem` soft deletion | Receipt assumes deletion after awaited write; no persisted readback. Undo calls `restoreMealItem`; no tombstone revision comparison. |
| `move_meal_item` | `moveMealItem`; Write / Local | Positive `itemId`; `mealType`: breakfast/lunch/dinner/snack | `getMealTypeForItem` → `moveMealItemToType`, one transaction preserving item identity and nutrition | Same diary day only. Receipt uses requested meal type. Undo moves to old type without checking later moves or restoring the original position. |
| `request_account_deletion` | `requestAccountDeletion`; Destructive / Server | None | Two confirmation stages, then pushes `/help/delete-account` | Opens the existing deletion flow; Coach does not itself delete the account. |
| `sign_out` | `signOut`; Sensitive / Server | None | `CloudBeforeSignOutSync.runBounded` → existing auth `signOut()` | Explicitly checks `currentSession == null` before success text. No compensating Undo. Not executed during this audit. |
| `log_water` | `addWater`; Write / Local | Required integer `amountMl` 1–5000 | `WaterRepository.add(occurredAt: DateTime.now(), amountMl: amount)` | Positive row ID and requested amount form the receipt; no post-write row query. Undo deletes that ID. Date is not an argument. |
| `log_weight` | `addWeight`; Write / Local | Required finite `weightKg` 20–500; optional canonical `date` | `WeightRepository.getForDay` → `addWeight`; existing day is updated, otherwise inserted | Positive row ID; receipt uses requested value/date. Undo deletes new row or restores captured prior row. No version fence. Coach always supplies `differentConditions`. |
| `save_memory` | `saveMemory`; Write / Local | Required trimmed `text` ≤500 characters; optional `kind`: user_fact/preference/constraint/goal/routine | `CoachMemoryRepository.saveConfirmed`: stores in local Preferences, then best-effort consent-gated cloud upsert | Returns the authored map, not storage readback. Identical text can reuse a previous memory ID, but Undo deletes that ID instead of restoring its earlier state. No version fence. |

The 11 local mutations above are the actual existing write surface. A new tool
should extend this native boundary and prove its repository effects, not merely
add a new label or navigation target. Existing `minimumTier` metadata defaults
to `free` for all descriptors; `_executeAction` does not enforce that metadata.
The separate Coach route entitlement gate remains in place and is outside this
audit's modification scope. This observation is not permission to alter
Premium, Trial, quota, or pricing behavior.

### The three additional enum actions

| Action enum absent from `BilToolRegistry` | Existing handler |
|---|---|
| `openDailyLog` | Opens `/daily-log`; preserves only the allowed `action` values barcode, voice, photo, water, notes, exercise. Generated local actions use this path. |
| `openAiCoachSubscription` | Pushes `/plans?focus=ai-coach`. Existing handoff only. |
| `buyAiBoost` | Pushes `/plans?focus=boost`. Existing handoff only; no purchase executed by this handler. |

`addWeight` also has a no-value navigation variant: it opens `/daily-check-in`
instead of saving. Thus enum presence alone cannot distinguish a write from a
route. The registry has two descriptors mapping to `navigate` and two to `reviewMeal`,
which accounts for the descriptor/enum counts.

### All 11 generic navigation targets

| Target | Route | Target | Route |
|---|---|---|---|
| `dashboard` | `/dashboard` | `daily_log` | `/daily-log` |
| `nutrition` | `/nutrition` | `weight_history` | `/weight-history` |
| `measurements` | `/advanced-body-measurements` | `goals` | `/goals` |
| `analytics` | `/analytics` | `profile` | `/profile-summary` |
| `settings` | `/settings` | `notifications` | `/notification-settings` |
| `ai_coach` | `/intelligence-center` | — | — |

These are the complete `navigate` tool targets. Feature-specific links and
workspace callbacks can open other verified routes; those are separate paths.

## 2. Admission, confirmation, persistence, and owner boundaries

The production admission paths currently differ:

1. [ModelBackedLocalCoachApi][local-api] normalizes input and calls the
   deterministic parser first. A nonempty deterministic result returns before
   the model is consulted.
2. Model actions pass through `_validatedModelAction` and
   `BilToolRegistry.createAction`, which validates arguments and supplies the
   canonical descriptor ID/type/risk.
3. [LocalCoachCommandParser.parse][parser] constructs actions directly, with
   IDs shaped as `add-water-<amount>`, `add-weight-<value>`, `update-goal-<value>`,
   `set-theme-dark`, `set-language-ar`, `manage-subscription`, and
   `request-account-deletion`. These are illustrative source ID shapes, not
   instructions or real user records. They do not match registry keys.
4. `_executeAction` looks up policy by `action.id` and checks permission only
   when the descriptor is non-null. For an unregistered ID it falls back to
   `action.requiresConfirmation`. Therefore deterministic writes can bypass
   the selected **read-only** mode while still presenting their usual
   confirmation. Confirmation is not equivalent to correct mode admission.

For recognized descriptors, reads and navigation are allowed in all modes;
local writes and sensitive/server actions are blocked in read-only mode.
Reversible writes ask in `askBeforeWrite`; sensitive/destructive actions retain
confirmation in `writeAllowed`; destructive actions require the second typed
confirmation. Low-risk settings changes do not ask, but should still respect
read-only mode.

`permissionMode` is captured before awaiting confirmation. The handler does not
re-read it immediately before the write. It also does not revalidate the
action's descriptor/type/arguments at that final execution boundary.
`_coachActionExecutionKey` is only `type:id`, and
`executingActionKeys` coalesces work only while it is in flight. It is not an
operation ID, payload digest, or durable idempotency journal.

The cloud gateway consumes only `proposed_actions.first`, and `LocalModelAnswer`
holds one action. Multiple food items must eventually travel as one validated
atomic batch command; treating an arbitrary list of independent writes as a
transaction would not establish all-or-nothing behavior. See
[local_model_gateway_io.dart][gateway].

The conversation persists message text, evidence JSON, safe action links, and a
special expiring goal proposal. `_retireDurableAction` removes a successful goal
proposal. Other writes remain transient. `_CoachUndoOperation` callbacks live
in the page's `undoOperations` map; receipt JSON surviving restart does not
restore a durable Undo operation. See [message serialization][messages],
[conversation persistence][persistence], and `_appendToolReceipt` /
`_undoCoachAction` in [the action handler][flow].

[databaseProvider][database-provider] recreates the database for an auth owner
change, and [LocalDatabaseScope][database-scope] uses separate account/guest
SQLite namespaces. That existing isolation must be preserved. Coach action
execution does not carry a captured owner/epoch through every async boundary;
several continuations and Undo callbacks re-read `WidgetRef` after awaiting.
The goal branch captures its repositories before its transaction, but still
has no operation-level owner/epoch check. File isolation alone does not prove
that late UI effects or a deferred callback target the correct account.

## 3. Repository truth and the defects to fix first

### Receipts

[BilActionReceipt.verified][receipt] currently means: `committed` is true,
the completion timestamp is positive, and any declared entity has a nonempty
ID. It does not check a repository readback, expected revision, operation hash,
or persisted result. `_appendToolReceipt` adds the label `BIL verified tool
result` even for its unstructured text-only results.

Most write branches do await real repositories. That is meaningful existing
functionality, but their receipt contents are derived from the request or a
captured pre-write object. The exception noted above is sign-out's explicit
auth session readback, not a general transaction receipt implementation.
Generic failure copy claims data stayed unchanged even though a failure after
a successful commit can occur, for example while retiring/persisting a goal
proposal. A commit result must distinguish no-write, committed, stale/conflict,
and committed-but-follow-up-failed states.

### Existing Undo

The Quick Add defect is concrete in [MealRepository][meal-repository]:
`createMeal` reuses a live bucket for the same day/type,
`addQuickMacroEntry` returns that bucket ID, and the Coach Undo calls
`deleteMealCascade` on it. The existing meal behavior fixture starts with food
in breakfast but adds Quick Add to an empty lunch; it does not cover older
food in the **same** bucket. Preserve that fixture and add the missing case.

All current compensations need operation/version checks before they overwrite
newer edits. The memory duplicate-ID case additionally needs a true before
snapshot. A quantity correction must retain the historical nutrient basis:
`updateMealItem` currently reloads the current `Food`, recalculates, and keeps
the old source/serving snapshot fields. If that Food changes, the displayed
provenance and the recalculated numbers can diverge.

### Unknown nutrition and totals

The repository can express unknown Quick Add fields using an evidence mask,
but the Coach's four required macro arguments and four `Known: true` flags
cannot express calorie-only input. `DailyLogRepository.readLedger` sums core
macros without testing their individual known bits; its fiber path does test
evidence. `CoachNutritionDay.knownTotals` and
`_coachNutritionDays` already preserve missing core/sodium evidence and should
be reused rather than weakened. See [the daily ledger][daily-ledger] and
[Coach context assembly][context-assembly].

`MealItems` snapshots 11 nutrients, source, verified status, and serving
size/unit, with UUID/revision/tombstone fields. It lacks distinct food-identity
confidence, quantity confidence, original measured/estimated quantity evidence,
and a full immutable food-reference revision. `Foods` has iron and vitamin C,
but `MealItems` and `NutrientEvidenceMask` do not snapshot them. Neither table
has cholesterol. `BaseDatabaseFoodAdapter` treats iron/vitamin-C default zeros
as known and treats most non-catalog legacy core zeros as authoritative.
Introducing an `estimated` source without updating this policy would lose
unknown semantics. See [MealItems][meal-items], [Foods][foods],
[evidence bits][evidence-mask], and [the database food adapter][food-adapter].

### Dates, food identity, and fixed user values

[CoachDateResolver][dates] recognizes several relative-day phrases against a
supplied local reference but does not parse explicit dates. The deterministic
parser supplies `DateTime.now()`; there is no typed IANA-zone/local-occurrence
contract for food commands. Its broad weight detection precedes meal intent,
so a food sentence containing a weight and a number within the body-weight
range can be classified as body weight. Food/body disambiguation must precede
mutation, with explicit-date priority and civil-day tests near midnight/DST.

`CoachMemoryRepository` stores confirmed text and kind, not a typed per-user
product/recipe definition with revision, serving conversion, and accepted
nutrient values. A fixed food quantity/value rule must be account scoped,
reviewable, and used by the food resolver. It must not become a global default.
The current daily weight upsert also cannot represent distinct morning/later
readings as separate facts; Coach supplies only the generic measurement context.

## 4. Every historical capability family, reconciled to current source

The statuses below describe the **Coach adapter**, not whether the independent
feature elsewhere in BIL exists. Source links identify the implementation or
existing native boundary to reuse. `No tool` means the complete current
descriptor/enum inventory has no corresponding semantic command.

| Capability family | Current Coach path | Remaining native connection |
|---|---|---|
| `food.log` | `reviewMeal` opens the diary; Quick Add writes supplied macros; Coach image flow produces reviewed text | Typed multi-food proposal → quantity/source review → atomic food-item commit → persisted readback and rich receipt. No `log_food_items` handler exists. |
| `food.correct` | `update_meal_item` updates a known item ID's grams | Resolve “half / instead / I meant”, food replacement and affected batch; expected revision, immutable reference, known flags, recalculation. |
| `food.move` | `move_meal_item` changes same-day meal bucket | Explicit date/day movement with stable item ID, expected revision and readback. |
| `food.delete` | `delete_meal_item` soft-deletes an item | Resolve intended item safely; persisted tombstone readback and version-bound Undo. |
| `body.weight` | `log_weight` and deterministic weight path write `WeightRepository` | Fix admission; explicit dates and measurement provenance; preserve separate readings where required; conflict-safe readback/Undo. |
| `day.energy` | No `set_daily_energy` command | Explicit calorie-only fact, all other nutrients unknown, no invented foods, correction/idempotency and no double-counting against food totals. Synthetic required case: 1905 kcal without meals. |
| `water.log` | `log_water` writes now; no date argument | Owner-safe operation/readback, explicit occurrence date/time and versioned Undo. |
| `operation.undo` | Text Undo and receipt-button callbacks in page memory | Durable operation ID, before/after revision, restart-safe lookup, single-flight Undo, conflict result, current owner checks. |
| `body.measurements` | `save_measurements` writes partial day snapshot | Readback and expected version; explicit time/provenance; preserve omitted values and unrelated newer edits. |
| `body.goal` | `update_goal` transaction already writes profile+goal | Retain rollback/latest-weight/durable-proposal behavior; add committed readback and version-safe Undo. |
| `body.history_analysis` | Context carries actual weight/body-model outputs; `navigate` opens weight history | Typed bounded history reads and evidence-linked trend answers; no claim that opening history performed a new analysis. |
| `recipes.portions` | `RecipeCoachLookup` / `CoachCatalogGrounding` read trusted recipe content and create real links | Reuse `MealRepository.addCalculatedRecipeServingAtomically` for reviewed recipe portions through the same transaction/receipt contract. |
| `nutrition.plans` | `open_plan` opens `/plan`; no diet activation tool | Adapt existing `DietPlanCommand.activate` / `DietPlanRepository` with its current authorization and readback; never conflate preview with activation. |
| `nutrition.analysis` | Context reads meals/targets; remaining tool and analytics route exist | Expose evidence-complete nutrient/day queries and consistent totals; reconcile unknown flags with daily ledger. |
| `sleep.history` | Context includes manual and connected sleep evidence | No sleep write/history tool. Reuse `DailyLogRepository.updateSleepHours` and its read path; manual sleep page already performs a saved-row readback. |
| `activity.steps` | Context and workspace timeline can expose connected activity; timeline opens `/connected-health/steps` | No step command. Read through `connectedHealthProvider`; preserve native permission/provenance and avoid synthetic measurements. |
| `activity.exercise` | Workout log route and verified catalog links; context has recorded activity | No Coach exercise write. Extract/adapt existing exercise logging boundary and refresh actual activity/energy policy. |
| `settings.language` | `set_language` changes durable app settings | Fix deterministic admission, revalidation and conflict-safe Undo. Preserve all 25 locales and locale-sync behavior. |
| `settings.appearance` | `set_theme_mode` changes durable app settings | Same admission/readback requirements; do not redesign the current reference surfaces. |
| `settings.units` | Settings page exists; no unit tool | Connect explicit unit preference via existing settings repository; a unit preference must not silently rewrite historical measured values. |
| `settings.notifications` | `navigate` can open notification settings | No preference/schedule command. Use the existing notification settings actions and real platform permission/result boundary. |
| `community.share` | Existing Coach/community UI handoffs; no semantic share/post tool | Explicit draft/composer intent and Earn explanation, preserving profile/code gates and user review. No automatic post or policy acceptance. |
| `community.messaging` | Community routes exist; no Coach message command | Resolve intended conversation/person and prepare reviewable draft. Sending requires explicit user intent and authoritative server result. |
| `community.connections` | Community connection routes exist; no Coach person/search/follow command | Typed read/search/BIL Code resolution, then separate explicit connection action with server readback. |
| `commerce.plans` | `/plans` handoffs exist | No Coach purchase execution. Keep current commerce/Trial/pricing behavior; this audit does not authorize changing it. |
| `commerce.restore` | No restore tool; existing Plans UI owns restoration | Preserve that verified restore path. Any future adapter must invoke the existing explicit flow; no billing-policy changes in this QA slice. |
| `account.export` | Export page exists; no export tool | `LocalExportRangePage._export` uses `LocalDataLifecycleService.exportCsvFiles` and `DataExportService.sharePortableCsvFiles`; add an explicit scoped export review, never automatic sharing. |
| `account.deletion` | Registered destructive handoff to `/help/delete-account` | Current action opens the user-owned deletion flow; do not label it “account deleted”. No additional deletion authority needed for Food V2. |
| `memory.review_delete` | `save_memory`; Coach menu opens `/decision-memory`; `DecisionMemoryPage` reads/deletes explicit memories | Add typed memory/product/recipe review and version-safe replacement/deletion; fix Undo of an already-existing memory. |
| `support.help` | `/help` exists; no semantic help tool or generic allow-list target for it | Add bounded help lookup and a true route handoff if needed, without claiming support contact occurred. |
| `admin.coach` | `/admin/ai-coach` exists; no admin Coach command | Keep admin authority in its existing gate; inventory allowed read/maintenance operations separately before exposing any tool. |

Other required capabilities omitted from the historical 31-entry map:

| Surface | Actual current boundary and next connection |
|---|---|
| Day close / reopen | `DailyLogRepository.closeDay`, `reopenDay`, `readLedger` exist. No Coach enum/descriptor calls them. Add explicit operation, version/readback, and day-state policy; do not emit a fictitious daily lock. |
| Fasting | `fasting_timer_actions.dart` persists session/history via `PreferencesRepository.mutate` and coordinates real notifications. No Coach adapter. Extract/reuse that command boundary with partial-notification-result semantics. |
| Notes and life context | Diary action routes and `LifeContextRepository` exist. No Coach write adapter. Preserve explicit context-use choices when adding one. |
| Photo food input | `_analyzeFoodImageInChat` performs consent → picker/camera → analysis → `showMealImageReviewDialog`, then appends text. It never calls `MealRepository`. Diary capture already maps reviewed candidates to trusted foods, converts units, and commits the batch; reuse it. |
| Voice food input | Native/cloud voice pipelines eventually call the common `ask`/understanding flow. They inherit the missing food transaction command; voice capture working is not evidence of food logging. |
| Barcode / label input | Workspace links to the existing diary barcode flow; `_applyInitialBarcode` validates identity and adds conversation context. Digits alone do not establish nutrients or a committed food item. |
| Rich food receipt and editing | Current tool receipts are text plus JSON evidence; no typed committed food-batch card. Add the native card from committed item snapshots, with exact reference layout and item/batch version-bound edit/Undo actions. |
| Salts/electrolytes and body calculations | Existing calculation/context code is reusable. Extend typed readbacks/presentation with explicit units and known flags; do not claim missing iron/vitamin-C/cholesterol snapshots are present. Preserve provenance/uncertainty for body-model outputs. |

Feature routes above were checked in [app_router.dart][router],
[Community routes][community-routes], and [wellness routes][wellness-routes].
The existing non-Coach boundaries are linked in the implementation source index
below; their presence is not an execution test.

## 5. Other existing Coach entry surfaces

The light [Coach workspace][workspace] displays current snapshot values only
when its existing verified entitlement permits them and their known flags are
present. Tabs are callbacks: Chat returns to conversation; Insights, Plan,
Progress, and Tools open analytics, plan, history, and diary routes.

Its Log a Meal card invokes `onPhoto`, Voice Log invokes `onVoice`, Quick Add
opens `/daily-log`, and Scan Product opens
`/daily-log?foodLog=1&action=barcode`. The photo path described above is still
analysis/review text only. Those labels must not be counted as four completed
semantic logging tools. Timeline links use real snapshot data and route to the
underlying diary, weight, water, and steps surfaces.

[CoachCatalogGrounding.answer][catalog] and [RecipeCoachLookup.answer][recipes]
provide useful existing catalog reads and verified content links. They do not
save a recipe serving or a performed workout. [Coach context assembly][context-assembly]
and [context preferences][context-preferences] already support bounded context
categories; preserve them when adding food/task context. A new food command
does not justify sending the user's whole health history to a model.

## 6. Smallest coherent native implementation sequence after R5

These are proposed QA implementation slices, not statements that they are
already integrated. Each slice keeps iOS 35 / Android 32 and Production
deployment unchanged.

1. **Correct action admission.** Route deterministic actions through canonical
   tool identity/argument validation. Keep operation identity separate from
   tool name; reject an unknown/mismatched mutation descriptor. Re-check mode
   and owner at the final write boundary after confirmation. Preserve existing
   safe no-value navigation and sensitive/destructive confirmation behavior.
   Add real widget cases for deterministic water/weight/settings in read-only
   mode and permission/owner change while confirmation is open.

2. **Fix targeted compensation and truthful commit results.** Return the new
   Quick Add item IDs in a typed mutation result while preserving existing
   repository callers. Undo only the created items, never the whole reused
   meal. Capture/restore an existing memory entry instead of deleting it.
   Centralize committed result/readback, distinguish post-commit failure, and
   add an operation record with owner, ID, digest, before/after version, and
   state. `PreferencesRepository.setManyInCurrentTransaction` is available for
   a bounded versioned local journal without casually introducing a database
   schema change; choose the durable representation deliberately.

3. **One real Food V2 vertical slice.** Start with an authorized, locally
   resolved set of food references and quantities. Carry explicit item/source/
   quantity evidence into one reviewed `log_food_items` proposal. Use a single
   native transaction to commit the entire batch and its operation result;
   replaying its ID returns the same result. Read back saved rows and build
   the rich receipt from those rows. Show the same entries/totals in diary,
   dashboard and reopened conversation. Reuse
   `addReviewedMealItemsAtomically`, quantity conversion, trusted-match review,
   and content-addressed calculated-recipe snapshots; extend them rather than
   overlaying an old implementation. Offer new model tools only through a
   compatible capability/protocol contract; Production's current single-action
   protocol must not be assumed to understand Food V2.

4. **Complete semantics on that transaction path.** Add explicit-date priority,
   user-local civil-day/timezone, one useful quantity question, declared
   estimates, multi-food corrections/replacements and same-as-yesterday.
   Resolve against versioned per-user fixed products/recipes before generic
   catalog/estimated data. Implement calorie-only day facts with unknown
   macros and an explicit non-double-counting rule. Quantity/source/known
   evidence must survive app restart, edits, moves, and Undo. Compare expected
   revisions before correction or compensation; never replay an old Undo over
   a newer edit.

5. **Extend capabilities family by family.** Reuse the same admission,
   transaction/readback and receipt contract for measurements, goal, water,
   day state, notes, sleep, fasting and exercise. Add bounded read tools for
   analytics/catalog/history and explicit adapters for settings and Community
   drafts. Keep purchases, Production actions, and automatic social sending
   outside this slice. Mark each table row with native test/receipt evidence
   only when that family's complete effect is proven.

6. **Close native visual fidelity alongside these slices.** Capture actual
   Flutter surfaces against the locked original Coach/Community references.
   The rich receipt must show persisted foods, quantities, known nutrients,
   sources and functional edit/Undo; no generated picture or current-screen
   golden can substitute for comparison to the original approved reference.

### Existing unmerged reference material worth porting selectively

The handoff's `BIL_Coach_V2_Local_Kit_2026-10-05.zip`, under
`bil_next_update/implementation`, contains reference concepts in
`src/contracts.ts`, `src/protocol.ts`, `src/dialogue.ts`, `src/food_resolver.ts`,
`src/time.ts`, `src/answer_policy.ts`, and `adapters/sqlite_ledger.mjs`. Useful pieces are typed
food/quantity provenance, owner-bound pending tasks, expected revisions,
operation idempotency/readback, targeted Undo, civil-time handling, and
absolute calorie-only facts. `tests/ledger.test.mjs` includes the relevant
pre-existing-meal/stale-Undo/replay scenarios.

These are reference TypeScript/Node implementations, not current Drift
integration or Flutter execution evidence. Port contracts and test ideas into
the current native architecture. Do not copy the old app overlay over newer
QA source. The candidate generic numeric `coach_commit_receipt.dart` alone is
not the required committed rich-food receipt.

## 7. Evidence and acceptance limits

Existing test definitions inspected for this inventory:

| Test source | Existing coverage visible in source | Important remaining case |
|---|---|---|
| `test/features/intelligence_center/ai_coach_tool_execution_behavior_test.dart` | Real repository writes for water/weight, measurements/goal, goal rollback/latest-weight/durable proposal, Quick Add/item edit/move/delete, settings/memory and compensating Undo | Same-bucket pre-existing Quick Add food; stale Undo; owner change; duplicate memory Undo; persisted result truth. |
| `test/features/intelligence_center/coach_action_permission_test.dart` | Descriptor policy in isolation | Actual deterministic-ID execution in read-only mode; mode change during confirmation. |
| `test/features/intelligence_center/ai_coach_navigation_receipt_test.dart` | Exact route handoffs, failed-open retry, contextual “open it”, Arabic weight-history route | No proof of mutations behind opened routes. |
| `test/features/intelligence_center/coach_intent_parity_test.dart` and `coach_date_resolver_test.dart` | Existing dialect/text/voice normalization and relative dates | Food/body-weight ambiguity, explicit-date precedence, timezone boundary/DST, multi-food corrections. |
| `test/repository_test.dart` | Atomic reviewed-food repository behavior | Native Coach batch operation/readback/idempotency integration. |
| `test/authoritative_daily_ledger_test.dart` and `test/features/daily_log/quick_macro_entry_dialog_test.dart` | Existing ledger/Quick Add evidence behavior | Unknown core macros in every daily projection; calorie-only non-double-counting. |
| `test/features/nutrition/meal_item_evidence_snapshot_test.dart` | Item evidence snapshots | Changing the referenced Food before quantity correction must not silently change the historical basis. |
| `test/features/daily_log/daily_log_food_add_flow_test.dart` | Existing diary food path | Reuse through Coach with identical persisted items, readback and rich receipt. |
| Coach catalog/context/category/voice/image/lifecycle test families | Existing useful boundaries and UI state-machine coverage | They cannot certify an absent native Food V2 command. |

No new functional tests were executed for this read-only inventory. Separately,
the preceding bounded localization/menu task executed the unchanged architecture
and composer contracts (15 passed), four Coach layout/accessibility cases
(iOS/Android × Arabic/English, large text plus keyboard), and focused analysis
of the two extracted Coach files (no issues). Those results establish that
specific extraction/accessibility change, not the capabilities proposed here.

For each implementation slice, retain existing assertions and add tests for
its actual missing behavior. The minimum Food V2 proof is a native user request
→ reviewed typed proposal → real Drift commit → committed readback → receipt
→ diary/dashboard refresh → reopening, plus rollback, same-operation retry,
stale correction/Undo and owner-switch cases. Paid/live-provider evaluation and
device/platform evidence remain separate authorization and acceptance work.

## Implementation source index

- [MealRepository][meal-repository]: atomic reviewed batch, calculated recipe,
  Quick Add, item edit/move/delete/restore, meal bucket reuse.
- [DailyLogRepository][daily-ledger]: day ledger, sleep, notes, close/reopen.
- [WeightRepository][weight-repository], [BodyMeasurementRepository][measurements],
  [GoalRepository][goals], [WaterRepository][water]: current health writes.
- [AppSettingsController][settings], [PreferencesRepository][preferences],
  [CoachMemoryRepository][memory]: settings, local atomic preferences, explicit memory.
- [Diary capture actions][diary-capture] and [Coach image flow][vision]: the
  current difference between actual reviewed-food logging and analysis text.
- [Diet plan command/repository][diet-plans], [manual sleep][sleep],
  [fasting actions][fasting], [connected health provider][connected-health]:
  existing native feature boundaries for later adapters.
- [DecisionMemoryPage][memory-page], [local export page][export-page],
  [notification settings actions][notification-settings]: existing user-owned
  review/control paths.

[tools]: ../../lib/features/intelligence_center/domain/bil_tool_registry.dart
[types]: ../../lib/features/intelligence_center/domain/intelligence_action.dart
[flow]: ../../lib/features/intelligence_center/presentation/intelligence_action_flow.dart
[permission]: ../../lib/features/intelligence_center/domain/coach_action_permission.dart
[navigation]: ../../lib/features/intelligence_center/domain/bil_navigation_registry.dart
[receipt]: ../../lib/features/intelligence_center/domain/bil_action_receipt.dart
[local-api]: ../../lib/features/intelligence_center/services/local_coach_api.dart
[parser]: ../../lib/features/intelligence_center/services/local_coach_command_parser.dart
[gateway]: ../../lib/features/intelligence_center/services/local_model_gateway_io.dart
[messages]: ../../lib/features/intelligence_center/domain/intelligence_message.dart
[persistence]: ../../lib/features/intelligence_center/presentation/intelligence_conversation_persistence.dart
[database-provider]: ../../lib/data/database/database_provider.dart
[database-scope]: ../../lib/data/database/database_scope.dart
[meal-repository]: ../../lib/data/repositories/meal_repository.dart
[daily-ledger]: ../../lib/data/repositories/daily_log_repository.dart
[context-assembly]: ../../lib/features/intelligence_center/services/coach_context_assembly.dart
[meal-items]: ../../lib/data/database/meal_items.dart
[foods]: ../../lib/data/database/foods.dart
[evidence-mask]: ../../lib/data/database/nutrient_evidence.dart
[food-adapter]: ../../lib/features/nutrition/adapters/database_food_adapter.dart
[dates]: ../../lib/features/intelligence_center/services/coach_date_resolver.dart
[router]: ../../lib/app/router/app_router.dart
[community-routes]: ../../lib/app/router/app_community_routes.dart
[wellness-routes]: ../../lib/app/router/app_wellness_routes.dart
[workspace]: ../../lib/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart
[catalog]: ../../lib/features/intelligence_center/services/coach_catalog_grounding.dart
[recipes]: ../../lib/features/intelligence_center/services/recipe_coach_lookup.dart
[context-preferences]: ../../lib/features/intelligence_center/domain/coach_context_preferences.dart
[weight-repository]: ../../lib/data/repositories/weight_repository.dart
[measurements]: ../../lib/data/repositories/body_measurement_repository.dart
[goals]: ../../lib/data/repositories/goal_repository.dart
[water]: ../../lib/data/repositories/water_repository.dart
[settings]: ../../lib/app/services/app_settings_provider.dart
[preferences]: ../../lib/data/repositories/preferences_repository.dart
[memory]: ../../lib/features/intelligence_center/services/coach_memory_repository.dart
[diary-capture]: ../../lib/features/daily_log/daily_log_capture_actions.dart
[vision]: ../../lib/features/intelligence_center/presentation/intelligence_vision_flow.dart
[diet-plans]: ../../lib/features/nutrition_plans/data/diet_plan_repository.dart
[sleep]: ../../lib/features/wellness/presentation/sleep_tracker_experience.dart
[fasting]: ../../lib/features/wellness/presentation/fasting_timer_actions.dart
[connected-health]: ../../lib/features/connected_health/providers/connected_health_provider.dart
[memory-page]: ../../lib/features/life_context/decision_memory_page.dart
[export-page]: ../../lib/features/settings/local_export_range_page.dart
[notification-settings]: ../../lib/features/notifications/presentation/notification_settings_actions.dart
