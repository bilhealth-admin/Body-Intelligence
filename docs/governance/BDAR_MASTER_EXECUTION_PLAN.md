# BDAR Master Execution Plan

Program: `BIL Dashboard Architecture Review and Reconstruction`

## Delivery policy

The latest uploaded project is the working baseline. The Product Owner should not need to upload the full repository after each package.

A new full archive is requested only when:

- the local repository materially diverges from the last verified package sequence;
- a package was edited manually;
- several commits were created outside the agreed workflow;
- a failure cannot be reproduced from the known baseline plus applied packages;
- a release-candidate audit requires a fresh complete snapshot.

## Package sequence

### Package BDAR-001 — Baseline Forensic Audit

Status: Delivered.

Outputs:

- package constitution;
- forensic audit;
- execution plan;
- decision log;
- preflight script;
- Quality Board and ledger alignment.

### Package BDAR-002 — Emergency Dashboard Integrity

Scope:

- repair all dashboard mojibake and corrupted punctuation;
- add repository-wide text-integrity regression test;
- reproduce and fix the apparent hidden/leaked insights surface;
- add compact, standard, and wide Arabic/English dashboard integrity tests;
- preserve the approved visual identity and all scientific content.

No new feature implementation.

### Package BDAR-003 — Deterministic Refresh and State Model

Scope:

- bounded refresh orchestration;
- partial-success state;
- deterministic completion;
- no indefinite refresh;
- targeted provider refresh tests;
- safe localized feedback.

### Package BDAR-004 — Dashboard Architecture Foundation

Scope:

- immutable `DashboardViewModel`;
- orchestration/controller boundary;
- typed section models;
- action coordinator;
- split monolithic widget responsibilities;
- no duplicated calculations;
- no behavior regression.

### Package BDAR-005 — Responsive Information Architecture

Scope:

- five-second rule;
- adaptive wide/medium/compact layouts;
- balanced use of width;
- no wasted half-screen;
- RTL/LTR parity;
- keyboard, focus, semantics, and text scaling;
- approved dashboard goldens.

### Package BIL-SETTINGS-001 — Settings Navigation and Profile Center

Scope:

- every child returns to Settings when opened from Settings;
- profile editing never restarts onboarding;
- canonical BIL number controls;
- save, discard, and return contracts;
- modern appearance labels while preserving stored values;
- profile and goal editing backed by existing repositories.

### Package BIL-LOCATION-001 — Region, City, and Timezone

Scope:

- country and city catalog;
- IANA timezone storage;
- device-timezone detection;
- optional explicit location permission;
- manual fallback;
- Windows, Android, iOS, and Web behavior.

### Package BIL-EXERCISE-001 — Exercise Domain Foundation

Scope:

- activity taxonomy;
- common-language and international names;
- walking, running, cycling, swimming, gym machines, and resistance training;
- duration, intensity, frequency, and session persistence;
- MET source metadata;
- estimated energy and uncertainty;
- double-counting prevention.

### Package BIL-EXERCISE-002 — Movement Energy Experience

Scope:

- premium movement-energy card;
- estimated activity energy;
- session breakdown;
- confidence/explanation;
- glass treatment that remains accessible;
- dashboard integration through the new architecture.

### Package BIL-NUTRITION-STRATEGY-001 — Strategy Contracts

Scope:

- scientific and product contracts;
- contraindication and safety boundary model;
- eligibility model;
- explainability;
- persistence and historical snapshot model;
- no strategy activation yet.

### Package BIL-NUTRITION-STRATEGY-002 — Core Strategies

Scope:

- Balanced;
- Mediterranean;
- DASH;
- Low carbohydrate;
- Maintenance;
- Fat loss;
- Lean bulk;
- Recomposition.

### Package BIL-NUTRITION-STRATEGY-003 — Advanced Strategies

Scope:

- Keto;
- Targeted Keto;
- Cyclical Keto;
- Carb Cycling;
- Intermittent Fasting;
- PSMF;
- Refeed;
- Diet Break.

Advanced strategies require stronger safety, evidence, and eligibility gates than general strategies.

### Package BIL-INTELLIGENCE-001 onward

- Adaptive TDEE
- Weight prediction
- Water retention
- Body composition
- Energy balance
- Recommendation engine
- Explainability engine
- confidence and missing-evidence system
- privacy-preserving AI layer

## Cross-platform release gate

No global-completion claim until:

- Windows verified;
- Android verified;
- Web persistence verified;
- iPhone/iPad build and device evidence recorded;
- RTL/LTR verified;
- accessibility verified;
- data migration and deletion safety verified;
- analyzer and approved tests pass;
- release notes and rollback evidence exist.
