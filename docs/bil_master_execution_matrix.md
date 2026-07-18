# BIL master execution matrix

> Binding execution ledger for the supplied BIL master backlog. This is not a feature-marketing roadmap.

## Coverage and rules

- Source SHA-256: `7e109984f8cc0c13a1de2f54b2d2be697759d25d65bc1e912c2da1faf4731c77`
- Parsed numbered occurrences: **1000**
- Deduplicated actionable sections: **550**
- Deduplication key: source part title + section number + section title; the longest repeated body is retained and normalized.
- Each entry preserves the complete source-section clause text in the Requirement field. A section may contain several clauses and is complete only when every clause passes.
- Status vocabulary: `complete`, `partial`, `missing and locally implementable`, `blocked by credentials/infrastructure`, `strategic/non-code`.
- A `complete` status requires repository evidence and a verified commit. Partial entries remain open even if some clauses already exist.
- External capabilities must remain disabled and must never report success until their blocker and acceptance criteria are fully satisfied.

## Status summary

- complete: **58**
- partial: **209**
- missing and locally implementable: **19**
- blocked by credentials/infrastructure: **185**
- strategic/non-code: **79**

## Requirement ledger

## Part 1 — Foundation

### BIL-FND-001 — Project Name

- **Source section:** Part 1 — Foundation / 1. Project Name
- **Requirement:** Body Intelligence Log (BIL) Official Short Name: BIL Tagline: Understand Your Body. One Better Decision Every Day. Arabic افهم جسمك... واتخذ قرارًا أفضل كل يوم.
- **Current repository status:** `complete`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** `7879f48`

### BIL-FND-002 — Vision Statement

- **Source section:** Part 1 — Foundation / 2. Vision Statement
- **Requirement:** BIL will become the world's most trusted personal body intelligence platform. It will not simply record calories. It will understand the body. It will explain what happened. It will explain why it believes that. It will explain what it does not know. It will remember what worked. It will improve every recommendation over time. It will never pretend certainty when evidence is weak. The user should eventually feel that BIL understands his own body better than any notebook, spreadsheet or calorie counter ever could.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-003 — Mission

- **Source section:** Part 1 — Foundation / 3. Mission
- **Requirement:** Give every human being an intelligent assistant that explains the body honestly. Not emotionally. Not commercially. Not through fear. Not through fake motivation. Only through understandable evidence.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-004 — Core Promise

- **Source section:** Part 1 — Foundation / 4. Core Promise
- **Requirement:** BIL does not replace doctors. BIL does not replace dietitians. BIL does not diagnose disease. BIL does not promise miracles. BIL promises something different. It promises to help people make one better decision every day.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-005 — Product Philosophy

- **Source section:** Part 1 — Foundation / 5. Product Philosophy
- **Requirement:** Every screen must answer one question: Does this genuinely help the user understand their body? If not... It does not belong inside BIL.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-006 — What BIL Is NOT

- **Source section:** Part 1 — Foundation / 6. What BIL Is NOT
- **Requirement:** BIL is NOT: another calorie counter another macro tracker another weight graph another barcode scanner another AI chatbot another fitness social network Those already exist. We are building something different.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-007 — What BIL Actually Is

- **Source section:** Part 1 — Foundation / 7. What BIL Actually Is
- **Requirement:** BIL is a Body Intelligence Platform. It observes. It remembers. It explains. It predicts carefully. It learns safely. It respects uncertainty.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-008 — Why BIL Exists

- **Source section:** Part 1 — Foundation / 8. Why BIL Exists
- **Requirement:** Millions of people fail because they receive numbers without understanding. Example: Weight increased. The application says nothing. User thinks: "I became fat." Reality: Maybe sodium. Maybe glycogen. Maybe water. Maybe bowel contents. Maybe poor sleep. Maybe late meal. Maybe measurement timing. Traditional apps stop at numbers. BIL begins there.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-009 — Our Biggest Competitor

- **Source section:** Part 1 — Foundation / 9. Our Biggest Competitor
- **Requirement:** Our competitor is not MyFitnessPal. It is confusion.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-010 — The Real Problem

- **Source section:** Part 1 — Foundation / 10. The Real Problem
- **Requirement:** People quit because they stop trusting themselves. Then they stop trusting the application. Then they stop logging. Then they stop trying. BIL exists to protect trust.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-011 — Trust Before Intelligence

- **Source section:** Part 1 — Foundation / 11. Trust Before Intelligence
- **Requirement:** Intelligence without trust is useless. Trust without intelligence becomes boring. BIL must have both.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-012 — The Golden Rule

- **Source section:** Part 1 — Foundation / 12. The Golden Rule
- **Requirement:** Never fake certainty. Never guess silently. Never invent explanations. Never hide uncertainty. Always explain confidence.
- **Current repository status:** `complete`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-FND-013 — Scientific Philosophy

- **Source section:** Part 1 — Foundation / 13. Scientific Philosophy
- **Requirement:** Evidence First. Assumptions Second. Marketing Last.
- **Current repository status:** `complete`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-FND-014 — User Emotion

- **Source section:** Part 1 — Foundation / 14. User Emotion
- **Requirement:** When opening BIL... The user should feel: "I'm safe." "My data belongs to me." "This application understands me." "I'm not being judged." "I'm not being manipulated." "I'm learning."
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-015 — Emotional Goals

- **Source section:** Part 1 — Foundation / 15. Emotional Goals
- **Requirement:** Never make users feel guilty. Never punish. Never shame. Never exaggerate. Never scare. Always educate. Always encourage. Always explain.
- **Current repository status:** `partial`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** —

### BIL-FND-016 — Design Philosophy

- **Source section:** Part 1 — Foundation / 16. Design Philosophy
- **Requirement:** Beauty attracts. Trust retains. Intelligence creates loyalty.
- **Current repository status:** `partial`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** —

### BIL-FND-017 — AI Philosophy

- **Source section:** Part 1 — Foundation / 17. AI Philosophy
- **Requirement:** AI is an assistant. Not the source of truth. The deterministic engine remains the authority. AI explains. AI translates. AI summarizes. AI teaches. AI never invents calculations.
- **Current repository status:** `complete`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** `12187e1`

### BIL-FND-018 — Privacy Philosophy

- **Source section:** Part 1 — Foundation / 18. Privacy Philosophy
- **Requirement:** Privacy is not a feature. Privacy is architecture. Everything begins with privacy.
- **Current repository status:** `complete`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** `1e29042`

### BIL-FND-019 — Offline Philosophy

- **Source section:** Part 1 — Foundation / 19. Offline Philosophy
- **Requirement:** Internet is optional. Your body is not. BIL must continue working even when the internet disappears.
- **Current repository status:** `complete`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** `49b0fa8`

### BIL-FND-020 — Cross Platform Philosophy

- **Source section:** Part 1 — Foundation / 20. Cross Platform Philosophy
- **Requirement:** The user owns one body. Therefore the user deserves one experience. Android. iPhone. iPad. Windows. Web. Future macOS. Everything should feel native. Everything should feel familiar. Everything should share one intelligent brain.
- **Current repository status:** `partial`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** —

### BIL-FND-021 — Data Philosophy

- **Source section:** Part 1 — Foundation / 21. Data Philosophy
- **Requirement:** Collect only data that creates value. If data has no purpose... Do not ask for it.
- **Current repository status:** `partial`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** —

### BIL-FND-022 — Every Input Needs A Reason

- **Source section:** Part 1 — Foundation / 22. Every Input Needs A Reason
- **Requirement:** If BIL asks for: Weight It must explain why. Sleep Water Users should never wonder: "Why is the app asking me this?"
- **Current repository status:** `partial`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** —

### BIL-FND-023 — Intelligence Philosophy

- **Source section:** Part 1 — Foundation / 23. Intelligence Philosophy
- **Requirement:** Raw Data ↓ Clean Data Reliable Data Understanding Explanation Recommendation Learning Better Recommendation
- **Current repository status:** `partial`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** —

### BIL-FND-024 — One Better Decision

- **Source section:** Part 1 — Foundation / 24. One Better Decision
- **Requirement:** This sentence defines BIL. Not: Lose weight faster. Eat fewer calories. Hit your macros. Instead: Help the user make ONE better decision today. Only one. Because consistency beats perfection.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-025 — Product Personality

- **Source section:** Part 1 — Foundation / 25. Product Personality
- **Requirement:** If BIL were a human... It would be: Calm. Patient. Highly educated. Honest. Respectful. Never arrogant. Never emotional. Never judgmental. Never dramatic. Always helpful.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-026 — Product Voice

- **Source section:** Part 1 — Foundation / 26. Product Voice
- **Requirement:** Avoid: "You failed." "You cheated." "You ruined your diet." Use: "Today's data is incomplete." "This fluctuation is common." "Let's continue." "We need more information." "There is no reason to change the plan today."
- **Current repository status:** `partial`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** —

### BIL-FND-027 — The User Must Feel Smarter

- **Source section:** Part 1 — Foundation / 27. The User Must Feel Smarter
- **Requirement:** Every session should leave the user understanding something new about their own body. Not merely seeing another chart.
- **Current repository status:** `partial`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** None
- **Completion commit:** —

### BIL-FND-028 — Long-Term Goal

- **Source section:** Part 1 — Foundation / 28. Long-Term Goal
- **Requirement:** Eventually users should say: "I understand my body now." Not: "I understand this app."
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-029 — Success Definition

- **Source section:** Part 1 — Foundation / 29. Success Definition
- **Requirement:** The best compliment is NOT: "This app has many features." It is: "This app understands me."
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-FND-030 — Final Principle

- **Source section:** Part 1 — Foundation / 30. Final Principle
- **Requirement:** If we must choose between: More Features or More Understanding We always choose: More Understanding. Official Product Vision Version 2.0
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/SCIENTIFIC_RULES.md`; `docs/ARCHITECTURE.md`; `lib/app`; `lib/engine`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Policy/document review plus engine, localization, privacy, and offline regression tests where executable.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

## Part 2 — Product Identity & Competitive Strategy

### BIL-IDN-031 — Why The World Needs BIL

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 31. Why The World Needs BIL
- **Requirement:** The world already has: calorie trackers macro trackers AI chatbots barcode scanners meal planners fitness apps Yet millions of people still quit. The problem is not the lack of features. The problem is the lack of understanding. BIL exists because people deserve explanations, not only numbers.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-032 — The Real Competitor

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 32. The Real Competitor
- **Requirement:** Our biggest competitor is not MyFitnessPal. It is uncertainty. Users quit because they stop believing. BIL exists to restore confidence.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-033 — Competing Against MyFitnessPal

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 33. Competing Against MyFitnessPal
- **Requirement:** MyFitnessPal excels at: Food database Barcode scanning Community Simplicity BIL will exceed it by: Explaining body changes Learning the user's body Adaptive recommendations Personal intelligence Scientific transparency Offline-first architecture Explainable AI
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-034 — Competing Against MacroFactor

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 34. Competing Against MacroFactor
- **Requirement:** MacroFactor excels at: Dynamic expenditure estimation Adaptive calorie targets BIL will extend this with: Body Twin Truth Engine Decision Memory Life Context Data Honesty Explainability Daily intelligence MacroFactor predicts. BIL predicts and explains.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-035 — Competing Against Cronometer

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 35. Competing Against Cronometer
- **Requirement:** Cronometer excels at: Micronutrients Accurate nutrition Laboratory-style detail BIL will keep that precision while adding: Human-readable explanations Daily decisions Behavioral coaching Adaptive learning Personal baselines
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-036 — Competing Against ZOE

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 36. Competing Against ZOE
- **Requirement:** ZOE excels at: Personalized nutrition Scientific branding Gut-health focus BIL will be broader. Not just nutrition. Body understanding. Lifestyle. Weight. Behavior. Learning. Decisions. Recovery. Context.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-037 — The Competitive Moat

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 37. The Competitive Moat
- **Requirement:** Anyone can copy: Barcode. Calories. Charts. Macros. Subscriptions. Community. AI Chat. Few can copy: Years of personal body understanding. That is the moat.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-038 — BIL Body Twin

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 38. BIL Body Twin
- **Requirement:** Every user gradually builds: One digital twin. Not one profile. The twin remembers: weight response water response sodium response carbohydrate response adherence consistency recovery normal fluctuation measurement habits No two twins are identical.
- **Current repository status:** `partial`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** —

### BIL-IDN-039 — Truth Before Motivation

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 39. Truth Before Motivation
- **Requirement:** Never motivate using lies. Never say: "You burned fat." unless supported. Instead: "The current data makes temporary water retention more likely." Honesty builds trust.
- **Current repository status:** `complete`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-IDN-040 — Explain Everything

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 40. Explain Everything
- **Requirement:** Every major number inside BIL must answer: Why? Examples: Calories. Protein. Water. TDEE. Weight trend. Prediction. Goal date. Body Twin. Every screen should contain a way to answer: "Why do you think that?"
- **Current repository status:** `partial`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** —

### BIL-IDN-041 — Every Recommendation Needs Evidence

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 41. Every Recommendation Needs Evidence
- **Requirement:** No recommendation appears without: Evidence. Confidence. Reason. Time horizon. Alternative explanation.
- **Current repository status:** `complete`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-IDN-042 — The Pyramid of Intelligence

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 42. The Pyramid of Intelligence
- **Requirement:** Level 1 Collect Data ↓ Level 2 Validate Data Level 3 Understand Data Level 4 Explain Data Level 5 Predict Carefully Level 6 Recommend Level 7 Learn Level 8 Become More Personal
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-043 — BIL Never Pretends

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 43. BIL Never Pretends
- **Requirement:** If confidence is low. Say confidence is low. If food logging is incomplete. Say it. If today's weight cannot be interpreted. Uncertainty is a feature.
- **Current repository status:** `complete`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-IDN-044 — Confidence Is Visible

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 44. Confidence Is Visible
- **Requirement:** Every important insight has: Confidence. Not hidden confidence. Visible confidence. Examples: ★★★★★ ★★★★☆ ★★★☆☆ or Very High High Moderate Low Insufficient Data
- **Current repository status:** `partial`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** —

### BIL-IDN-045 — Data Honesty

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 45. Data Honesty
- **Requirement:** Separate two ideas: Health and Data Quality A healthy person may have poor logging. An unhealthy person may have excellent logging. Never confuse the two.
- **Current repository status:** `complete`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-IDN-046 — Understanding Beats Precision

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 46. Understanding Beats Precision
- **Requirement:** Wrong precision destroys trust. Example: 68.32% looks scientific. It often isn't. Better: Very Likely Likely Possible Unlikely Unknown
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-047 — Simplicity Is Intelligence

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 47. Simplicity Is Intelligence
- **Requirement:** A smart application reduces work. It never increases work. If users repeatedly enter: Same breakfast. Same lunch. Same coffee. Same water. Same meals. BIL learns.
- **Current repository status:** `partial`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** —

### BIL-IDN-048 — Adaptive Logging

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 48. Adaptive Logging
- **Requirement:** Eventually BIL should ask: "Did you have your usual breakfast?" One tap. Done. Less effort. More consistency.
- **Current repository status:** `partial`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** —

### BIL-IDN-049 — Invisible Intelligence

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 49. Invisible Intelligence
- **Requirement:** The smartest AI is often invisible. Users should not constantly think: "I'm talking to AI." Instead: "The app understands me."
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-050 — One Best Action

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 50. One Best Action
- **Requirement:** Most apps create stress. BIL creates clarity. Never show: 15 goals. Always show: One Best Action. Examples: Drink 600 ml. Add protein. Do nothing today. Stay patient. Log today's weight.
- **Current repository status:** `complete`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-IDN-051 — Decision Memory

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 51. Decision Memory
- **Requirement:** The application remembers: Advice. Outcome. Success. Failure. Confidence. Then improves.
- **Current repository status:** `complete`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** `4c4e420`

### BIL-IDN-052 — Recovery Is Success

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 52. Recovery Is Success
- **Requirement:** People disappear. Life happens. Vacation. Illness. Ramadan. Travel. Stress. New baby. Work. Recovery Mode welcomes them back. No guilt.
- **Current repository status:** `complete`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** `d4f6c29`

### BIL-IDN-053 — Every Day Should Feel Different

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 53. Every Day Should Feel Different
- **Requirement:** Users should never feel they are reopening yesterday. Each day answers: What changed? What matters today? What should I do?
- **Current repository status:** `partial`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** —

### BIL-IDN-054 — Personal Baseline

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 54. Personal Baseline
- **Requirement:** Never compare users to averages only. Compare users to themselves. Your sodium. Your water. Your sleep. Your trend. Your body.
- **Current repository status:** `partial`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** —

### BIL-IDN-055 — Explanation Before Prediction

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 55. Explanation Before Prediction
- **Requirement:** Prediction without explanation creates anxiety. Explanation before prediction creates confidence.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-056 — Less Noise

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 56. Less Noise
- **Requirement:** Avoid flooding dashboards. If everything is important. Nothing is important.
- **Current repository status:** `partial`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** —

### BIL-IDN-057 — Beautiful Doesn't Mean Complex

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 57. Beautiful Doesn't Mean Complex
- **Requirement:** Premium means: Readable. Calm. Fast. Organized. Purposeful. Not overloaded.
- **Current repository status:** `partial`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** —

### BIL-IDN-058 — Every Screen Has A Purpose

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 58. Every Screen Has A Purpose
- **Requirement:** No decorative screens. Every screen answers a question. Every button solves a problem. Every chart tells a story.
- **Current repository status:** `partial`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** None
- **Completion commit:** —

### BIL-IDN-059 — We Build Habits

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 59. We Build Habits
- **Requirement:** Not addiction. BIL should never manipulate. No fake urgency. No psychological traps. No guilt loops.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-IDN-060 — Long-Term Vision

- **Source section:** Part 2 — Product Identity & Competitive Strategy / 60. Long-Term Vision
- **Requirement:** Years later. Users should not say: "I logged food." They should say: "I learned my body."
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `docs/SCIENTIFIC_RULES.md`; `lib/engine`; `lib/features/dashboard`; `lib/features/life_context`
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Deterministic engine tests and Today/analytics widget tests; product-strategy review for non-code clauses.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

## Part 3 — User Experience Philosophy (UX Manifesto)

### BIL-UX-061 — The First 10 Seconds

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 61. The First 10 Seconds
- **Requirement:** The first launch determines whether the user will ever return. The first impression must communicate: This app is premium. This app is fast. This app respects me. This app understands me. This app is different. The user must feel excitement, not confusion.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-062 — The First Question

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 62. The First Question
- **Requirement:** Do not start by asking for twenty fields. Start by asking: "Let's understand your body together." Everything afterwards should feel like a conversation, not a government form.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-063 — Every Screen Must Answer One Question

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 63. Every Screen Must Answer One Question
- **Requirement:** Users should never wonder: "What am I supposed to do here?" Every screen must have a single primary purpose. Examples: Today → What should I do today? Diary → What have I eaten today? Analytics → What is happening to my body? Body Twin → What may happen next? Settings → How do I personalize my experience?
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-064 — One Primary Action

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 64. One Primary Action
- **Requirement:** Every screen has ONE primary button. Never five competing buttons. Never ten floating actions. One clear action. Everything else is secondary.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-065 — Navigation Philosophy

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 65. Navigation Philosophy
- **Requirement:** The user should reach any important feature in: Maximum: Three taps. If something needs five taps... Redesign it.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-066 — Zero Learning Curve

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 66. Zero Learning Curve
- **Requirement:** The application should feel familiar immediately. A first-time user should understand: where to add food where to add water where to enter weight where to ask AI where today's progress is without reading documentation.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-067 — Remove Cognitive Load

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 67. Remove Cognitive Load
- **Requirement:** The application must think. The user should not. Examples: Instead of: Choose meal. Choose category. Choose favorites. Choose database. Choose serving. Choose units. Choose meal order. Instead: Search. Select. Done.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-068 — Intelligent Defaults

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 68. Intelligent Defaults
- **Requirement:** Never ask users questions when BIL already knows the answer. Examples: Country. Language. Units. Recent breakfast. Favorite coffee. Typical lunch. The app remembers.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-069 — Daily Flow

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 69. Daily Flow
- **Requirement:** Every day should follow a natural rhythm. Morning ↓ Daily Check-in Weight Today's Insight Meals Water Progress One Best Action Done No unnecessary interruptions.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-070 — The Today Screen

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 70. The Today Screen
- **Requirement:** The Today screen is the heart of BIL. Everything else supports Today. If Today is weak... The product is weak.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-071 — The Today Screen Answers

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 71. The Today Screen Answers
- **Requirement:** Did I weigh today? Where am I? How much remains? What changed? What should I do? How confident is BIL? Nothing more. Nothing less.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-072 — Empty States Matter

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 72. Empty States Matter
- **Requirement:** Never show: "No Data." Instead show: "Let's build your understanding together." or "Log today's weight to unlock trend analysis." Empty states should motivate. Not disappoint.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-073 — Success Feels Quiet

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 73. Success Feels Quiet
- **Requirement:** Do not celebrate everything. Celebrate meaningful moments. Examples: First week. First month. Goal reached. Perfect consistency. Body Twin unlocked. Recovery completed. Avoid childish fireworks. Aim for elegant satisfaction.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-074 — Error Messages

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 74. Error Messages
- **Requirement:** Never say: Error 500 Invalid field Unknown failure Instead: "We couldn't save today's meal." "Your internet connection appears unavailable." "Everything is still stored safely on your device." Always explain. Always reassure.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** `5acc9cc`

### BIL-UX-075 — Confirmation Philosophy

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 75. Confirmation Philosophy
- **Requirement:** Never ask: "Are you sure?" without context. Instead: "Delete today's weight? This cannot be undone." Clear. Simple. Respectful.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-076 — Speed Is UX

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 76. Speed Is UX
- **Requirement:** The user perceives waiting as poor quality. Target: Immediate response. Skeleton loading. Lazy loading. Background processing. Never blank screens.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-077 — Motion Philosophy

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 77. Motion Philosophy
- **Requirement:** Animation must explain. Not entertain. Animation guides attention. Animation confirms success. Animation softens transitions. Animation should never delay work.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-078 — Touch Targets

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 78. Touch Targets
- **Requirement:** Every tappable element should be comfortable. Never tiny. Never crowded. Never frustrating.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-079 — Accessibility Is Premium

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 79. Accessibility Is Premium
- **Requirement:** Accessibility is not optional. Support: Large text. Screen readers. High contrast. Reduced motion. Keyboard navigation. VoiceOver. TalkBack. Mouse. Touch. Stylus. Everyone deserves the same quality.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-080 — Colors Have Meaning

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 80. Colors Have Meaning
- **Requirement:** Green does not always mean good. Red does not always mean bad. Context determines meaning. Example: For weight gain: Higher calories may be positive. For weight loss: Higher calories may require attention. Never hardcode emotions into colors.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-081 — Typography

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 81. Typography
- **Requirement:** Users read more than they tap. Typography must be: Elegant. Readable. Consistent. Never decorative.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-082 — Dark Mode

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 82. Dark Mode
- **Requirement:** Dark mode is not an inverted light theme. It is independently designed. Charts. Cards. Icons. Shadows. Spacing. Contrast. Everything should be optimized.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** `40b621b`

### BIL-UX-083 — Arabic Is First-Class

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 83. Arabic Is First-Class
- **Requirement:** Arabic is not a translated interface. Arabic is a native experience. RTL must feel intentional. Typography must be optimized. Spacing must be mirrored correctly. Icons should respect RTL where appropriate.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** `c58c437`

### BIL-UX-084 — English Is Also Native

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 84. English Is Also Native
- **Requirement:** English should feel like it was designed first. Never translated awkwardly. Never mixed. Never inconsistent.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** `c58c437`

### BIL-UX-085 — Forms

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 85. Forms
- **Requirement:** Forms should never intimidate. Break long forms into steps. Provide progress. Auto-save. Auto-focus intelligently. Restore unfinished work.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-086 — Search

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 86. Search
- **Requirement:** Search should feel instant. Results should appear while typing. Recent searches. Favorites. Personal ranking. Country relevance. Meal relevance. The user should rarely need to finish typing.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

### BIL-UX-087 — Food Logging

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 87. Food Logging
- **Requirement:** Adding food should be faster than writing it in Notes. If logging becomes annoying... Users stop logging.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** `20975e3`

### BIL-UX-088 — Water Logging

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 88. Water Logging
- **Requirement:** Water should always be visible. One tap. Done. Never hidden in menus.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** `eba2a61`

### BIL-UX-089 — AI Entry

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 89. AI Entry
- **Requirement:** The AI should never dominate the interface. It should always be available. But never intrusive. It helps. It does not interrupt.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** Requires a real server-side AI/provider boundary and production credentials; the current local client must keep this capability unavailable.
- **Completion commit:** —

### BIL-UX-090 — Every Pixel Has A Job

- **Source section:** Part 3 — User Experience Philosophy (UX Manifesto) / 90. Every Pixel Has A Job
- **Requirement:** Nothing exists only for decoration. Every icon. Every card. Every color. Every animation. Every shadow. Every label. Every space. Must have a reason. If it has no purpose... Remove it. بعده
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/app/localization`; `lib/app/router`; `lib/features`; `lib/shared/widgets`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Responsive bilingual widget tests, accessibility semantics, golden tests, and manual keyboard/screen-reader QA.
- **Blocker:** None
- **Completion commit:** —

## Part 4 — Design Principles (The BIL Design DNA)

### BIL-DSN-091 — The First Feeling

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 91. The First Feeling
- **Requirement:** Before the user reads a single word... He must feel: This application is expensive. Even if it is free. Premium is a feeling. Not a price.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-092 — Visual Identity

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 92. Visual Identity
- **Requirement:** BIL should become recognizable from one screenshot. Just like: Apple. Spotify. Notion. Linear. Arc. People should immediately know: "This is BIL."
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-093 — Simplicity Wins

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 93. Simplicity Wins
- **Requirement:** Every extra element must justify its existence. If removing something improves clarity... Remove it.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-094 — Calm Over Excitement

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 94. Calm Over Excitement
- **Requirement:** Health applications should reduce anxiety. Not create stimulation. Avoid: Neon colors. Aggressive animations. Flashing elements. Visual overload. Choose: Soft gradients. Natural spacing. Readable typography. Comfortable contrast.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-095 — Luxury Through Restraint

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 95. Luxury Through Restraint
- **Requirement:** Luxury is not adding more. Luxury is removing everything unnecessary.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-096 — White Space Is A Feature

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 96. White Space Is A Feature
- **Requirement:** Do not fear empty space. Empty space guides attention. Crowded screens create stress.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-097 — Card Philosophy

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 97. Card Philosophy
- **Requirement:** Cards should feel like physical information panels. Every card answers one question. Never mix unrelated information.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-098 — Visual Hierarchy

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 98. Visual Hierarchy
- **Requirement:** Every screen has: Primary focus. Secondary information. Supporting details. Never equal importance everywhere.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-099 — One Hero Element

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 99. One Hero Element
- **Requirement:** Every screen contains exactly one visual hero. Examples: Today's Weight. Today's Action. Body Twin Projection. Weekly Progress. Everything else supports it.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-100 — Colors

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 100. Colors
- **Requirement:** Primary Color Trust. Secondary Color Guidance. Success Progress. Warning Attention. Error Action required. Never use color only. Always combine with: Icons. Text. Shapes.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-101 — Typography Hierarchy

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 101. Typography Hierarchy
- **Requirement:** Large Story. Medium Decision. Small Details. Tiny Avoid whenever possible.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-102 — Buttons

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 102. Buttons
- **Requirement:** Buttons must communicate priority. Primary One only. Secondary Supporting. Text Button Low priority. Danger Rare.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-103 — Icons

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 103. Icons
- **Requirement:** Icons explain. They never replace text completely. Every important action must remain understandable without guessing icons.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-104 — Motion

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 104. Motion
- **Requirement:** Every animation answers: "What changed?" Animations never exist for decoration.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-105 — Duration

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 105. Duration
- **Requirement:** Instant 100–150ms Small transition 200ms Navigation 250–350ms Celebration 500–800ms Never exceed user patience.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-106 — Haptics

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 106. Haptics
- **Requirement:** Subtle. Meaningful. Never constant. Examples: Goal reached. Weight saved. Meal logged. Milestone achieved. Never vibrate for every tap.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-107 — Glassmorphism

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 107. Glassmorphism
- **Requirement:** Use carefully. Only where hierarchy improves. Never reduce readability. Never imitate Apple blindly. Purpose first.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-108 — Shadows

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 108. Shadows
- **Requirement:** Soft. Natural. Consistent. Not dramatic.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-109 — Corners

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 109. Corners
- **Requirement:** Rounded. Friendly. Professional. Never childish.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-110 — Charts

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 110. Charts
- **Requirement:** Charts must tell stories. Not show mathematics. Every chart should answer: "What does this mean?" Not only: "What happened?"
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-111 — Empty Charts

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 111. Empty Charts
- **Requirement:** Don't show empty graphs. Instead: Explain what will appear. Motivate the user.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-112 — Dashboard Philosophy

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 112. Dashboard Philosophy
- **Requirement:** Dashboard ≠ Statistics. Dashboard = Decisions.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-113 — Analytics Philosophy

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 113. Analytics Philosophy
- **Requirement:** Analytics should educate. Not overwhelm.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-114 — AI Philosophy Inside UI

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 114. AI Philosophy Inside UI
- **Requirement:** AI never interrupts. AI waits. When the user needs help... AI appears naturally.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** Requires a real server-side AI/provider boundary and production credentials; the current local client must keep this capability unavailable.
- **Completion commit:** —

### BIL-DSN-115 — Loading States

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 115. Loading States
- **Requirement:** Never show blank white pages. Always use: Skeletons. Progress placeholders. Cached content. Immediate shell.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-116 — Error Screens

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 116. Error Screens
- **Requirement:** Beautiful. Human. Helpful. Never technical. Example: "We couldn't load today's data." Retry. Offline mode. Explanation.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-117 — Delight

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 117. Delight
- **Requirement:** Tiny moments. Tiny smiles. Tiny rewards. Never casino psychology.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-118 — Celebration

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 118. Celebration
- **Requirement:** Celebrate: Recovery. Consistency. Milestones. Personal records. Learning. Not: Lowest calories. Fastest weight loss. Extreme deficits.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-119 — Theme Philosophy

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 119. Theme Philosophy
- **Requirement:** Light Mode Clean. Professional. Airy. Dark Mode Elegant. Comfortable. Rich. Not simply inverted colors.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** `40b621b`

### BIL-DSN-120 — Every Screen Must Feel Alive

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 120. Every Screen Must Feel Alive
- **Requirement:** Static screens feel abandoned. Use: Subtle transitions. Responsive feedback. Smooth scrolling. Micro animations. Gentle progress. Everything should communicate: "This application is carefully crafted."
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-121 — Native Feeling

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 121. Native Feeling
- **Requirement:** Android users should feel: "This is an excellent Android app." iPhone users should feel: "This belongs on iOS." Windows users should feel: "This is a desktop application." Web users should feel: "This is a premium web experience." Not: "This is a Flutter app."
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-122 — Premium Means Invisible Quality

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 122. Premium Means Invisible Quality
- **Requirement:** Users rarely notice: Spacing. Animation timing. Consistency. Alignment. Touch response. Typography. But they immediately notice when these are wrong. Perfection lives in invisible details.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-123 — Visual Trust

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 123. Visual Trust
- **Requirement:** People trust beautiful products more. Beauty is not vanity. Beauty creates confidence. Confidence increases consistency. Consistency changes lives.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-124 — The BIL Standard

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 124. The BIL Standard
- **Requirement:** Before releasing any screen ask: Would Apple ship this? Would Google approve this? Would Linear be proud of this? Would Notion accept this quality? If not... Improve it.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-DSN-125 — Final Design Principle

- **Source section:** Part 4 — Design Principles (The BIL Design DNA) / 125. Final Design Principle
- **Requirement:** The application should never look like: A student project. A Flutter template. A clone. A dashboard generator. It should look like: The future of personal health intelligence. تمام # BIL Vision 2.0
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app/theme`; `lib/core/theme`; `lib/shared/widgets`; feature presentation widgets
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Golden, responsive, contrast, reduced-motion, large-text, keyboard, and screen-reader tests.
- **Blocker:** None
- **Completion commit:** —

## Part 5 — The Intelligence Philosophy (The Brain of BIL)

### BIL-INT-126 — Intelligence Before Artificial Intelligence

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 126. Intelligence Before Artificial Intelligence
- **Requirement:** BIL must never depend on AI to appear intelligent. If every AI service disappears tomorrow... BIL must still be the smartest body application. AI enhances. Deterministic science remains the foundation.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-127 — Explain Everything

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 127. Explain Everything
- **Requirement:** Every important number must answer: Why? Not only: What?
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-128 — Every Recommendation Needs Evidence

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 128. Every Recommendation Needs Evidence
- **Requirement:** BIL never says: "Eat more protein." Instead it says: "We recommend increasing protein because your average intake during the last 12 days was 27g below your target, while muscle preservation is one of your selected goals."
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-INT-129 — Confidence Matters

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 129. Confidence Matters
- **Requirement:** Every recommendation includes confidence. Examples: ★★★★★ ★★★★☆ ★★★☆☆ Or High Medium Low Never hide uncertainty.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-INT-130 — Admitting Ignorance Builds Trust

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 130. Admitting Ignorance Builds Trust
- **Requirement:** Sometimes the smartest answer is: "I don't know yet." Examples: Not enough weight entries. Not enough calorie logs. Large data gap. Travel period. Illness. Measurement inconsistency. The application becomes more trustworthy by admitting limits.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-INT-131 — Body Twin Philosophy

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 131. Body Twin Philosophy
- **Requirement:** The Body Twin is not a prediction engine. It is a learning engine. It improves continuously. It never claims certainty.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-132 — Personal Baseline

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 132. Personal Baseline
- **Requirement:** Never compare users with averages first. Compare them with themselves. The baseline becomes more valuable every month.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-133 — Adaptive Intelligence

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 133. Adaptive Intelligence
- **Requirement:** The application should become: More accurate. More personal. More helpful. Every week.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-134 — Context Changes Everything

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 134. Context Changes Everything
- **Requirement:** The same weight gain means different things if: User travelled. User slept badly. User trained heavily. User ate high sodium. User fasted. Context is intelligence.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-135 — Truth Engine Philosophy

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 135. Truth Engine Philosophy
- **Requirement:** Truth Engine exists to reduce panic. Not create excitement. When weight increases: Explain. Reassure. Educate. Never shock.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-INT-136 — Recommendations Must Be Practical

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 136. Recommendations Must Be Practical
- **Requirement:** Advice should always be realistic. Bad: Exercise two hours. Good: Walk ten minutes after dinner.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-137 — One Decision Rule

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 137. One Decision Rule
- **Requirement:** Users remember one decision. Not ten. BIL always prioritizes.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-INT-138 — Intelligence Should Feel Invisible

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 138. Intelligence Should Feel Invisible
- **Requirement:** Users should think: "This application understands me." Not: "This application is using AI."
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-139 — AI Is A Guide

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 139. AI Is A Guide
- **Requirement:** Never an authority. Never a doctor. Never an unquestionable source.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** Requires a real server-side AI/provider boundary and production credentials; the current local client must keep this capability unavailable.
- **Completion commit:** —

### BIL-INT-140 — AI Must Respect Deterministic Logic

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 140. AI Must Respect Deterministic Logic
- **Requirement:** If deterministic calculations say: TDEE = 2480 AI cannot invent: 2600 It must use the trusted engine.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** `12187e1`

### BIL-INT-141 — AI Must Explain

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 141. AI Must Explain
- **Requirement:** Every answer should reference evidence. Never hallucinate.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** Requires a real server-side AI/provider boundary and production credentials; the current local client must keep this capability unavailable.
- **Completion commit:** —

### BIL-INT-142 — Memory Philosophy

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 142. Memory Philosophy
- **Requirement:** Remember only useful things. Forget unnecessary things. Memory exists to help. Not to profile.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-143 — Decision Memory

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 143. Decision Memory
- **Requirement:** The application remembers: Recommendations. User actions. Outcomes. Learning. Not private conversations without purpose.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** `4c4e420`

### BIL-INT-144 — Food Intelligence

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 144. Food Intelligence
- **Requirement:** Food search should improve automatically. Frequently used foods move upward. Rare foods move downward. The user notices the improvement. Without configuring anything.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-145 — Speed Is Intelligence

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 145. Speed Is Intelligence
- **Requirement:** If finding breakfast takes: 12 seconds The application is not intelligent. Even if AI exists.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-146 — Intelligence Must Save Time

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 146. Intelligence Must Save Time
- **Requirement:** Every month the user should spend less effort. Never more.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-147 — Recovery Is Part Of Intelligence

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 147. Recovery Is Part Of Intelligence
- **Requirement:** Stopping logging is normal. Returning must be easy.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** `d4f6c29`

### BIL-INT-148 — AI Never Judges

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 148. AI Never Judges
- **Requirement:** No guilt. No shame. No manipulation. No fear. Only support.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-149 — Recommendations Should Learn

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 149. Recommendations Should Learn
- **Requirement:** If advice repeatedly fails... Stop repeating it. Try another approach.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-150 — Explain Before Predicting

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 150. Explain Before Predicting
- **Requirement:** Never predict without explaining. Users trust explanations.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-151 — Data Quality Controls Intelligence

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 151. Data Quality Controls Intelligence
- **Requirement:** Bad data. Weak confidence. Never pretend otherwise.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-INT-152 — Continuous Calibration

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 152. Continuous Calibration
- **Requirement:** Every prediction should improve over time. If it becomes worse... The application should recognize this.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-153 — No Magic Numbers

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 153. No Magic Numbers
- **Requirement:** Never invent precision. Instead of: 68.231% Prefer: Likely. Moderately likely. Very likely. Unless statistically justified.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-154 — Body Twin Is Personal

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 154. Body Twin Is Personal
- **Requirement:** Two identical people should still receive different guidance. Because history matters.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-155 — Intelligence Must Remain Fast

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 155. Intelligence Must Remain Fast
- **Requirement:** Thinking should not delay interaction. Background processing. Caching. Incremental updates.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-156 — Weekly Reflection

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 156. Weekly Reflection
- **Requirement:** Every week BIL should answer: What did we learn? Not: How many charts changed?
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** `d4f6c29`

### BIL-INT-157 — Intelligence Should Reduce Anxiety

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 157. Intelligence Should Reduce Anxiety
- **Requirement:** Every explanation should make users calmer. More informed. More confident.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-158 — Never Pretend To Diagnose

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 158. Never Pretend To Diagnose
- **Requirement:** BIL supports healthy decisions. It does not diagnose diseases.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-INT-159 — Personal Evolution

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 159. Personal Evolution
- **Requirement:** The application evolves with the user. Beginner. Intermediate. Advanced. Professional. Without changing identity.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

### BIL-INT-160 — Final Intelligence Principle

- **Source section:** Part 5 — The Intelligence Philosophy (The Brain of BIL) / 160. Final Intelligence Principle
- **Requirement:** A truly intelligent application does not overwhelm users with information. It quietly gives them the right insight at the right moment, with the right level of confidence, helping them make one better decision every day. تمام ممتاز. أرسل اللي بعده. # Premium UI Bible
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine`; `lib/features/dashboard`; `lib/features/analytics`; `lib/features/life_context`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Pure-Dart deterministic engine tests covering sufficiency, confidence, evidence, alternatives, and safety language.
- **Blocker:** None
- **Completion commit:** —

## Part 5 — Dashboard, Today Screen & Daily Experience

### BIL-TDY-161 — The Home Screen Must Be Calm

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 161. The Home Screen Must Be Calm
- **Requirement:** When users open BIL they should immediately understand: Where they are. What changed. What matters today. What action should be taken. Nothing else.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-162 — Information Hierarchy

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 162. Information Hierarchy
- **Requirement:** Order of importance: Daily Check-in What Changed Today One Best Action Today's Progress Meals Water Activity Insights Quick Actions
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-163 — Daily Check-in Card

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 163. Daily Check-in Card
- **Requirement:** Always appears at the top when today's weight is missing. Contains: Wheel Picker Text Field Save Skip Today After saving: Card disappears. Smooth animation.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-164 — What Changed Today Card

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 164. What Changed Today Card
- **Requirement:** Large premium card. Contains: Title Summary Confidence Expand Button Never overwhelming.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-TDY-165 — One Best Action Card

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 165. One Best Action Card
- **Requirement:** Large colorful card. Contains: One recommendation only. Examples: Drink 700 ml more. Log lunch. Eat 30 g protein. Keep today's plan.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-TDY-166 — Confidence Ring

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 166. Confidence Ring
- **Requirement:** Circular indicator. Green Blue Orange Red Shows: Today's analysis reliability.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-167 — Today's Calories

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 167. Today's Calories
- **Requirement:** Card contains: Consumed Target Remaining Large typography. Animated progress ring.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-168 — Macronutrients

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 168. Macronutrients
- **Requirement:** Three premium cards: Protein Carbs Fat Each shows: Consumed Target Remaining Color adapts to goal.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-169 — Micronutrients

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 169. Micronutrients
- **Requirement:** Expandable section. Shows: Sodium Potassium Magnesium Calcium Fiber Sugar Only if available.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-170 — Water Card

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 170. Water Card
- **Requirement:** Beautiful wave animation. Large progress. Quick buttons: +250 +500 +750 Custom
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-171 — Meals Timeline

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 171. Meals Timeline
- **Requirement:** Instead of list. Use timeline. Breakfast ↓ Lunch Dinner Snack Each meal expandable.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-172 — Meal Card

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 172. Meal Card
- **Requirement:** Contains: Meal icon Calories Foods Time Protein Quick Edit
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-173 — Quick Add Button

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 173. Quick Add Button
- **Requirement:** Floating Action Button. Opens sheet. Options: Food Water Weight Barcode Ask BIL
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-174 — Ask BIL

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 174. Ask BIL
- **Requirement:** Beautiful entry point. Premium. Never oversized. Unavailable state clearly explained.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-175 — Progress Rings

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 175. Progress Rings
- **Requirement:** Never use thick childish circles. Elegant. Thin. Animated. Premium.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-176 — Dashboard Charts

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 176. Dashboard Charts
- **Requirement:** Rounded. Interactive. Zoomable. Smooth. No sharp edges.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-177 — Trend Line

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 177. Trend Line
- **Requirement:** Weight trend: Smoothed. Raw data optional. Confidence shading.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-178 — Weekly Progress

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 178. Weekly Progress
- **Requirement:** Horizontal card. Shows: Start Today Goal Difference
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-179 — Goal Progress

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 179. Goal Progress
- **Requirement:** Beautiful circular visualization. Percentage. Days remaining. Expected date.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** `98515db`

### BIL-TDY-180 — Weight Trend

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 180. Weight Trend
- **Requirement:** Primary color. Current point highlighted. Tap for details.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** `b6ef7da`

### BIL-TDY-181 — Empty Dashboard

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 181. Empty Dashboard
- **Requirement:** Never blank. Instead: Welcome. Let's start today.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-182 — Daily Motivation

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 182. Daily Motivation
- **Requirement:** Not random quotes. Only contextual encouragement. Example: Three consecutive days logged. Great consistency.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-183 — Notifications

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 183. Notifications
- **Requirement:** Never intrusive. Quiet reminders. Context aware.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-184 — Scroll Experience

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 184. Scroll Experience
- **Requirement:** Natural. Momentum. No lag.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-185 — Sticky Header

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 185. Sticky Header
- **Requirement:** Small. Elegant. Contains: Date Today's status Profile
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-186 — Cards

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 186. Cards
- **Requirement:** Rounded. 16–24dp radius. Soft shadow. Consistent spacing.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-187 — Touch Feedback

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 187. Touch Feedback
- **Requirement:** Ripple. Scale. Haptic. Fast.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-188 — Animation Duration

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 188. Animation Duration
- **Requirement:** Small interactions: 150–220ms Transitions: 250–350ms Screen transitions: 300–450ms
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-189 — Loading Dashboard

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 189. Loading Dashboard
- **Requirement:** Skeleton UI. Never spinner only.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-190 — Refresh

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 190. Refresh
- **Requirement:** Pull-to-refresh. Smooth. Shows: Updated successfully.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-191 — Search Everywhere

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 191. Search Everywhere
- **Requirement:** Search always accessible. Never hidden deeply.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-192 — Fast Entry

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 192. Fast Entry
- **Requirement:** User should log breakfast in under: 5 seconds.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-193 — Context Menu

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 193. Context Menu
- **Requirement:** Long press: Edit Duplicate Favorite Delete
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-194 — Bottom Navigation

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 194. Bottom Navigation
- **Requirement:** Compact screens: Today Diary Progress Food Profile
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** `ab056d4`

### BIL-TDY-195 — Navigation Rail

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 195. Navigation Rail
- **Requirement:** Desktop. Tablet. Web. Adaptive automatically.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** `ab056d4`

### BIL-TDY-196 — Desktop Dashboard

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 196. Desktop Dashboard
- **Requirement:** Centered content. Maximum width. Panels. Not stretched.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-197 — Tablet Layout

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 197. Tablet Layout
- **Requirement:** Two columns. Natural spacing.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-198 — Landscape

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 198. Landscape
- **Requirement:** Never waste space. Use panels.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-199 — Accessibility

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 199. Accessibility
- **Requirement:** Everything reachable. Keyboard. Mouse. Screen Reader. Large text.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

### BIL-TDY-200 — Final Dashboard Principle

- **Source section:** Part 5 — Dashboard, Today Screen & Daily Experience / 200. Final Dashboard Principle
- **Requirement:** The Today screen should feel like opening the dashboard of your own body—not a spreadsheet, not a calorie calculator, but a calm control center that immediately tells you: What happened, where you stand, and what the single best next step is. # Premium UI Bible
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/features/dashboard`; `lib/features/daily_check_in`; `lib/features/daily_log`; `lib/app/router`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Dashboard/check-in/diary widget and repository tests using real local data, plus responsive/accessibility coverage.
- **Blocker:** None
- **Completion commit:** —

## Part 1 — Core AI Platform & Intelligence Layer

### BIL-AI-001 — Mission

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 1. Mission
- **Requirement:** The AI inside BIL exists to assist, explain, and educate. It never replaces the deterministic health engine. It never invents numbers. It never diagnoses disease.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-002 — Core Principle

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 2. Core Principle
- **Requirement:** Deterministic Engine = Source of Truth AI = Natural Language Layer Meaning: Calories, TDEE, macros, Body Twin, Truth Engine and analytics always come from BIL itself. The AI only explains them.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-003 — AI Responsibilities

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 3. AI Responsibilities
- **Requirement:** The AI may: explain results answer nutrition questions compare weeks recommend food choices summarize progress explain weight changes answer "why?" teach healthy habits help users navigate the application
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-004 — AI Must Never

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 4. AI Must Never
- **Requirement:** Never: invent calories invent nutrients diagnose illness prescribe medication replace physicians change user goals automatically modify data without permission
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-005 — AI Personality

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 5. AI Personality
- **Requirement:** The assistant should feel: calm intelligent encouraging scientific honest humble Never robotic. Never manipulative. Never overly emotional.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-006 — Brand Identity

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 6. Brand Identity
- **Requirement:** Possible official names: BIL Guide BIL Coach Ask BIL BIL Intelligence BIL Companion Avoid names implying licensed medical care.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-007 — Languages

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 7. Languages
- **Requirement:** Support: Arabic English Future: French Spanish German Turkish
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-008 — Context Awareness

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 8. Context Awareness
- **Requirement:** The AI should know (with permission): today's weight trend calorie target calories consumed meals protein water activity goal Body Twin Truth Engine One Best Action
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-009 — Permission Model

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 9. Permission Model
- **Requirement:** Before using personal data: Request consent. Users can disable: weight access food access notes history coach data
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-010 — Session Context

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 10. Session Context
- **Requirement:** Each conversation should receive only the minimum required context. Never the full database.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-011 — Memory

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 11. Memory
- **Requirement:** Conversation memory: Temporary by default. Persistent only with permission.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-012 — User Controls

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 12. User Controls
- **Requirement:** Users can: clear conversations export conversations disable AI revoke permissions
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-013 — AI Modes

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 13. AI Modes
- **Requirement:** Three modes: Beginner Standard Advanced
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-014 — Beginner Mode

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 14. Beginner Mode
- **Requirement:** Simple language. Short explanations. No technical terms.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-015 — Standard Mode

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 15. Standard Mode
- **Requirement:** Balanced detail.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-016 — Advanced Mode

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 16. Advanced Mode
- **Requirement:** Includes: confidence evidence assumptions limitations
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-017 — Conversation Types

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 17. Conversation Types
- **Requirement:** Nutrition Weight Body Twin Truth Engine Progress Meals Hydration Goals Application Help
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-018 — Food Questions

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 18. Food Questions
- **Requirement:** Examples: How many calories in rice? Best protein breakfast? High potassium foods? Fiber sources?
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-019 — Food Search

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 19. Food Search
- **Requirement:** AI should query BIL food database. Not invent nutrition.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-020 — Food Selection

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 20. Food Selection
- **Requirement:** When multiple foods exist: Present options. User confirms. Then log.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-021 — Logging Flow

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 21. Logging Flow
- **Requirement:** AI asks: Do you want me to add this meal? Never auto-log.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-022 — Water Flow

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 22. Water Flow
- **Requirement:** Example: "I drank 500 ml." AI asks: Add 500 ml to today? Confirmation required.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-023 — Weight Flow

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 23. Weight Flow
- **Requirement:** Example: "I weigh 82.3 kg." AI: Would you like to replace today's weight?
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-024 — Safe Writes

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 24. Safe Writes
- **Requirement:** Every database modification requires confirmation.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-025 — Explain TDEE

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 25. Explain TDEE
- **Requirement:** AI explains: Formula Observed trend Confidence Missing data
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-026 — Explain Weight Change

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 26. Explain Weight Change
- **Requirement:** AI references Truth Engine. Never invent causes.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-027 — Explain Body Twin

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 27. Explain Body Twin
- **Requirement:** Uses current simulation. Explains assumptions.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-028 — Compare Weeks

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 28. Compare Weeks
- **Requirement:** AI summarizes: Weight Calories Protein Water Consistency
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-029 — Compare Months

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 29. Compare Months
- **Requirement:** Highlight: Improvements Challenges Recommendations
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-030 — One Best Action

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 30. One Best Action
- **Requirement:** AI explains: Why BIL chose today's action.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-031 — Confidence

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 31. Confidence
- **Requirement:** Every recommendation should mention: High Medium Low
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-032 — Missing Data

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 32. Missing Data
- **Requirement:** AI should clearly state: More data needed.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-033 — Sources

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 33. Sources
- **Requirement:** If answering nutritional questions: Mention source. Example: USDA OpenFoodFacts Manufacturer
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-034 — Hallucination Policy

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 34. Hallucination Policy
- **Requirement:** If unsure: Say so. Never guess.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-035 — Medical Safety

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 35. Medical Safety
- **Requirement:** For alarming symptoms: Advise professional medical evaluation. Never diagnose.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-036 — Eating Disorders

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 36. Eating Disorders
- **Requirement:** Respond safely. Avoid harmful coaching.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-037 — Dangerous Weight Loss

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 37. Dangerous Weight Loss
- **Requirement:** Warn appropriately.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-038 — Harmful Requests

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 38. Harmful Requests
- **Requirement:** Refuse politely.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-039 — Cost Management

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 39. Cost Management
- **Requirement:** Support: Token limits Daily quotas Caching
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-040 — Multiple Providers

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 40. Multiple Providers
- **Requirement:** Provider abstraction. Support: OpenAI Gemini Anthropic Azure OpenAI Future local models
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-041 — Provider Switching

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 41. Provider Switching
- **Requirement:** Changing providers must not require rewriting the application.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-042 — Server Architecture

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 42. Server Architecture
- **Requirement:** All AI requests go through backend. Never expose API keys.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-043 — Authentication

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 43. Authentication
- **Requirement:** AI available only to authenticated entitlement.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-044 — Offline Mode

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 44. Offline Mode
- **Requirement:** If offline: Explain AI unavailable. Offer deterministic features.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-045 — Conversation Export

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 45. Conversation Export
- **Requirement:** PDF Markdown Text
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-046 — Conversation Delete

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 46. Conversation Delete
- **Requirement:** Permanent deletion.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-047 — Privacy

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 47. Privacy
- **Requirement:** Never use conversations for training without explicit consent.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-AI-048 — Audit Logs

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 48. Audit Logs
- **Requirement:** Administrative logs: Anonymous where possible.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-049 — Analytics

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 49. Analytics
- **Requirement:** Collect only: usage latency errors Never chat contents without permission.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** Requires an owned server, provider credentials kept off-client, consent/redaction, abuse controls, rate/cost limits, monitoring, and verified adapters.
- **Completion commit:** —

### BIL-AI-050 — Final AI Principle

- **Source section:** Part 1 — Core AI Platform & Intelligence Layer / 50. Final AI Principle
- **Requirement:** The AI should never try to impress the user. Its purpose is to help the user understand their body, make informed decisions, and trust BIL because it is consistently accurate, transparent, and honest. Cloud Architecture
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/engine/ai_write_policy.dart`; `lib/app/environment`; `docs/ROADMAP.md`; future server/provider adapters
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Provider-contract, consent, redaction, prompt-injection, deterministic-tool, safe-write, deletion/export, cost, and outage integration tests.
- **Blocker:** None
- **Completion commit:** —

## Part 1 — Offline-First Cloud & Synchronization Platform

### BIL-CLD-001 — Mission

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 1. Mission
- **Requirement:** The cloud exists to synchronize the user's data. It must never become a requirement for using BIL. The application must always remain usable without Internet.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-002 — Core Philosophy

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 2. Core Philosophy
- **Requirement:** Offline First. Cloud Second. The user never waits for the cloud before using the application.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-003 — Source of Truth

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 3. Source of Truth
- **Requirement:** Every device has its own local database. The cloud is the synchronization layer. Not the live database.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** `84e5633`

### BIL-CLD-004 — Local Database

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 4. Local Database
- **Requirement:** Store locally: Profile Weight Foods Meals Water Analytics Goals Body Twin Decision Memory Life Context Everything works offline.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** `84e5633`

### BIL-CLD-005 — Cloud Responsibilities

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 5. Cloud Responsibilities
- **Requirement:** Cloud handles: Sync Backup Restore Multi-device access Authentication Subscription state AI requests Coach platform Community
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-006 — Login

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 6. Login
- **Requirement:** Supported: Email Apple Google Microsoft Guest Mode
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-007 — Guest Mode

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 7. Guest Mode
- **Requirement:** Users can start immediately. No registration required. Later: Convert local profile into cloud account. Without losing any data.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** `8c42e95`

### BIL-CLD-008 — Local → Cloud Migration

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 8. Local → Cloud Migration
- **Requirement:** When user creates an account: Upload: Profile History Meals Weights Water Goals Decision Memory Safely.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-009 — Incremental Sync

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 9. Incremental Sync
- **Requirement:** Never upload everything. Only changes.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-010 — Delta Synchronization

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 10. Delta Synchronization
- **Requirement:** Every object contains: Created Updated Deleted Version Revision Device ID
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-011 — Tombstones

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 11. Tombstones
- **Requirement:** Deleted records remain as deletion markers. Prevent deleted items from returning.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** `20975e3`

### BIL-CLD-012 — Conflict Detection

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 12. Conflict Detection
- **Requirement:** Detect: Two devices editing the same object.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-013 — Conflict Resolution

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 13. Conflict Resolution
- **Requirement:** Priority: Newest revision Otherwise: Ask user.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-014 — Merge Strategy

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 14. Merge Strategy
- **Requirement:** Independent objects merge automatically. Conflicting edits require deterministic rules.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-015 — Sync Queue

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 15. Sync Queue
- **Requirement:** Every device contains: Outgoing queue Incoming queue Retry queue
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-016 — Background Sync

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 16. Background Sync
- **Requirement:** Runs automatically. Never interrupts usage.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-017 — Retry Logic

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 17. Retry Logic
- **Requirement:** Network unavailable? Retry later. No data loss.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-018 — Sync Status

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 18. Sync Status
- **Requirement:** Show: Synced Syncing Offline Conflict Error
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-019 — Manual Sync

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 19. Manual Sync
- **Requirement:** Allow: Sync Now
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-020 — Selective Sync

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 20. Selective Sync
- **Requirement:** Users choose: Weights Meals Foods Water Notes AI Coach Community
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-021 — Encryption

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 21. Encryption
- **Requirement:** TLS during transport. Encrypted storage on backend.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-022 — Device Registration

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 22. Device Registration
- **Requirement:** Each device receives: Device ID Friendly name Platform Last active
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-023 — Device Management

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 23. Device Management
- **Requirement:** User can: Rename device. Remove device. Logout remotely.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-024 — Session Management

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 24. Session Management
- **Requirement:** Show: Current device Other devices Login time IP region (approximate)
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-025 — Backup

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 25. Backup
- **Requirement:** Automatic cloud backup.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-026 — Restore

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 26. Restore
- **Requirement:** Restore any account to a new device.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-027 — Export

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 27. Export
- **Requirement:** Export: JSON CSV PDF ZIP
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** `1e29042`

### BIL-CLD-028 — Delete Account

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 28. Delete Account
- **Requirement:** Delete: Authentication Cloud data Sessions Backups Community identity According to retention policy.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-029 — Privacy Controls

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 29. Privacy Controls
- **Requirement:** User chooses: What syncs.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-030 — AI Data

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 30. AI Data
- **Requirement:** AI conversations synced separately. Optional.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-031 — Coach Data

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 31. Coach Data
- **Requirement:** Coach only sees: Shared information. Never hidden data.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-032 — Community Data

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 32. Community Data
- **Requirement:** Separate from health data.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-033 — File Storage

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 33. File Storage
- **Requirement:** Future support: Photos Reports Exports Progress cards
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-034 — Storage Buckets

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 34. Storage Buckets
- **Requirement:** Separate buckets: Images Exports Community Coach Temporary
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-035 — Upload Rules

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 35. Upload Rules
- **Requirement:** Maximum size. Virus scanning. Secure filenames.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-036 — Download Rules

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 36. Download Rules
- **Requirement:** Authenticated. Authorized. Temporary URLs.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-037 — Row Level Security

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 37. Row Level Security
- **Requirement:** Every user accesses only their own data. Unless explicitly shared.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-038 — Sharing

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 38. Sharing
- **Requirement:** Coach. Family. Friends. Research. All require consent.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-039 — Revocation

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 39. Revocation
- **Requirement:** Access revoked instantly.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-040 — Notifications

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 40. Notifications
- **Requirement:** Cloud delivers: Coach messages. Friend requests. Challenges. Updates.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-041 — Offline Notifications

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 41. Offline Notifications
- **Requirement:** Queued until connection returns.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-042 — Sync Performance

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 42. Sync Performance
- **Requirement:** Target: Small payloads. Compression. Pagination. Batch uploads.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-043 — Scalability

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 43. Scalability
- **Requirement:** Architecture supports: Millions of users. Without redesign.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-044 — Monitoring

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 44. Monitoring
- **Requirement:** Track: Sync failures. Latency. Conflict frequency. Queue sizes.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-045 — Disaster Recovery

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 45. Disaster Recovery
- **Requirement:** Multiple backups. Point-in-time recovery.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-046 — Regional Deployment

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 46. Regional Deployment
- **Requirement:** Future: US Europe Middle East Asia Choose nearest region.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-047 — GDPR & Privacy

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 47. GDPR & Privacy
- **Requirement:** Support: Export Deletion Consent Data minimization
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-048 — Health Data

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 48. Health Data
- **Requirement:** Treat as sensitive. Higher protection.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

### BIL-CLD-049 — Future Expansion

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 49. Future Expansion
- **Requirement:** Cloud prepared for: Wearables Apple Health Google Health Connect Clinics Research API integrations
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** Requires an owned cloud project, authentication, audited schema/RLS, secure secrets, sync workers, monitoring, and multi-device test infrastructure.
- **Completion commit:** —

### BIL-CLD-050 — Final Cloud Principle

- **Source section:** Part 1 — Offline-First Cloud & Synchronization Platform / 50. Final Cloud Principle
- **Requirement:** The user should never think: "I hope my data syncs." They should simply use BIL naturally, while synchronization happens quietly, securely, reliably, and invisibly in the background. Cloud Architecture
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/data/database`; `lib/data/repositories`; `lib/engine/sync_conflict_engine.dart`; `docs/DATABASE.md`; future sync service
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Migration, tombstone, outbox/inbox, conflict, RLS, multi-device, retry, backup/restore, privacy, and offline integration tests.
- **Blocker:** None
- **Completion commit:** —

## Part 1 — Professional Coach & Clinic Ecosystem

### BIL-COA-001 — Mission

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 1. Mission
- **Requirement:** The Coach Platform transforms BIL from a personal tracking application into a complete coaching ecosystem. Users remain owners of their data. Coaches receive access only with explicit permission.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-002 — Core Philosophy

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 2. Core Philosophy
- **Requirement:** The coach supports the user. The coach never owns the user's data. The user may revoke access at any moment.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-003 — Platform Roles

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 3. Platform Roles
- **Requirement:** Support: User Coach Nutritionist Trainer Clinic Administrator Future: Research Organization Healthcare Provider
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-004 — Verification

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 4. Verification
- **Requirement:** Professional accounts require verification. Examples: Professional license. Certification. Identity. Business verification. Never allow anyone to falsely appear as a licensed professional.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-005 — Coach Profile

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 5. Coach Profile
- **Requirement:** Each coach has: Name Photo Biography Country Languages Specialties Years of experience Certifications Ratings Reviews Pricing Availability
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-006 — Search Coaches

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 6. Search Coaches
- **Requirement:** Search by: Country Language Specialty Price Rating Online status
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-007 — Coach Discovery

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 7. Coach Discovery
- **Requirement:** Users can browse: Featured Popular Nearby Recently joined Highest rated
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-008 — Coach Dashboard

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 8. Coach Dashboard
- **Requirement:** Shows: Today's clients Unread messages Pending reviews Upcoming check-ins Renewals Statistics
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-009 — Client List

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 9. Client List
- **Requirement:** Each client card shows: Name Goal Current weight Trend Last activity Adherence Risk indicator Permission status
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-010 — Permission System

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 10. Permission System
- **Requirement:** User chooses exactly what the coach may see. Examples: Weight Meals Water Macros Micronutrients Photos (future) AI conversations Notes Body Twin Decision Memory
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-011 — Permission Changes

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 11. Permission Changes
- **Requirement:** Permissions can be modified anytime. Changes apply immediately.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-012 — Revoke Access

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 12. Revoke Access
- **Requirement:** One button. Instant revocation. No hidden copies remain accessible.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-013 — Coaching Packages

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 13. Coaching Packages
- **Requirement:** Support: Monthly Quarterly Annual Custom packages.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-014 — Coach Plans

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 14. Coach Plans
- **Requirement:** Coach may create: Meal plans Macro targets Water goals Exercise plans Habits Challenges
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-015 — Approval Workflow

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 15. Approval Workflow
- **Requirement:** Coach suggestions never overwrite user settings automatically. User reviews changes. Accepts or rejects.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-016 — Check-ins

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 16. Check-ins
- **Requirement:** Scheduled: Weekly Biweekly Monthly Custom
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-017 — Progress Reports

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 17. Progress Reports
- **Requirement:** Automatically generated. Coach may add comments.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-018 — Notes

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 18. Notes
- **Requirement:** Private coach notes. Private user notes. Shared notes. Clearly separated.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-019 — Messaging

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 19. Messaging
- **Requirement:** Dedicated Coach Chat. Separate from Community Chat.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-020 — Attachments

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 20. Attachments
- **Requirement:** Future support: PDF Meal plans Images Reports
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-021 — Notifications

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 21. Notifications
- **Requirement:** Coach receives: New client Completed check-in Plan accepted Plan rejected Message received
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-022 — User Notifications

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 22. User Notifications
- **Requirement:** User receives: Coach message Updated plan Review reminder Check-in reminder
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-023 — Meal Plan Builder

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 23. Meal Plan Builder
- **Requirement:** Coach creates: Meals Foods Portions Schedules Alternatives
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-024 — Exercise Plans

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 24. Exercise Plans
- **Requirement:** Future integration.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-025 — Goal Updates

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 25. Goal Updates
- **Requirement:** Coach suggests. User confirms. BIL recalculates automatically.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-026 — Analytics

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 26. Analytics
- **Requirement:** Coach sees trends. Never raw database tables.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-027 — Body Twin Access

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 27. Body Twin Access
- **Requirement:** Optional. User-controlled.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-028 — Truth Engine

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 28. Truth Engine
- **Requirement:** Coach sees explanations. Not hidden calculations.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-029 — Decision Memory

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 29. Decision Memory
- **Requirement:** Coach can reference previous successful interventions. Never hidden profiling.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-030 — Weekly Review

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 30. Weekly Review
- **Requirement:** Automatically shared if user allows.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-031 — Video Calls

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 31. Video Calls
- **Requirement:** Future module.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-032 — Audio Messages

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 32. Audio Messages
- **Requirement:** Future module.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-033 — Calendar

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 33. Calendar
- **Requirement:** Appointments. Availability. Time zones.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-034 — Payments

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 34. Payments
- **Requirement:** Coach subscriptions. Session purchases. Package purchases. Clinic billing.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-035 — Refund Policy

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 35. Refund Policy
- **Requirement:** Transparent.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-036 — Ratings

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 36. Ratings
- **Requirement:** Verified clients only.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-037 — Reviews

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 37. Reviews
- **Requirement:** Moderated. No fake reviews.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-038 — Coach Analytics

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 38. Coach Analytics
- **Requirement:** Retention. Client improvements. Response time. Adherence.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-039 — Clinic Dashboard

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 39. Clinic Dashboard
- **Requirement:** Multiple coaches. Shared administration. Separate permissions.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-040 — Clinic Roles

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 40. Clinic Roles
- **Requirement:** Owner Manager Coach Assistant Reception
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-041 — Audit Trail

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 41. Audit Trail
- **Requirement:** Every important action recorded. Who. When. What changed.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-042 — Security

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 42. Security
- **Requirement:** All communications encrypted.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-043 — Data Ownership

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 43. Data Ownership
- **Requirement:** User owns: Health data. Coach owns: Professional notes. Shared data follows permission rules.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-044 — Export

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 44. Export
- **Requirement:** User exports all coaching history.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-045 — Account Closure

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 45. Account Closure
- **Requirement:** Coach loses access immediately.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-046 — Professional Ethics

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 46. Professional Ethics
- **Requirement:** No misleading claims. No hidden advertising. No diagnosis without proper authority.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-047 — International Readiness

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 47. International Readiness
- **Requirement:** Supports: Currencies Languages Time zones Regional regulations
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-048 — Scalability

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 48. Scalability
- **Requirement:** Architecture supports: Independent coaches. Large clinics. Hospital networks. Future enterprise.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-049 — Future Expansion

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 49. Future Expansion
- **Requirement:** Prepared for: Telehealth Wearables Lab integration Insurance Employer wellness
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

### BIL-COA-050 — Final Coach Principle

- **Source section:** Part 1 — Professional Coach & Clinic Ecosystem / 50. Final Coach Principle
- **Requirement:** The Coach Platform should feel like a secure collaboration between the user and a trusted professional—not surveillance, not control, and never ownership of the user's health data. Commerce System
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/ROADMAP.md`; future authenticated coach/clinic backend and client features
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Role/RLS, consent/revocation, audit, messaging, payment, deletion/export, and abuse-safety end-to-end tests.
- **Blocker:** Requires verified professional identities, authenticated multi-tenant backend/RLS, moderation, consent/revocation, communications, legal policy, and operations.
- **Completion commit:** —

## Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform

### BIL-COM-001 — Mission

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 1. Mission
- **Requirement:** The Commerce System exists to fund the continued development of BIL while remaining fair, transparent, and respectful to users.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-002 — Philosophy

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 2. Philosophy
- **Requirement:** The application must never feel like it is constantly trying to sell. The value should convince users to subscribe. Not pressure.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-003 — Subscription Plans

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 3. Subscription Plans
- **Requirement:** Support: Free Plus Pro Family Coach Clinic Each plan has its own entitlement profile.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-004 — Subscription Durations

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 4. Subscription Durations
- **Requirement:** Support: Monthly 3 Months Annual Future: Lifetime (optional)
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-005 — Pricing Model

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 5. Pricing Model
- **Requirement:** Support: Global pricing Regional pricing Country overrides Currency conversion Promotional pricing
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-006 — Local Currency

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 6. Local Currency
- **Requirement:** Automatically display: USD EUR GBP EGP JOD SAR AED ...and others.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-007 — Introductory Pricing

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 7. Introductory Pricing
- **Requirement:** Support: First month discount First year discount Intro offers Must comply with store rules.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-008 — Free Trial

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 8. Free Trial
- **Requirement:** Optional. Configurable. Visible. Transparent.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-009 — Trial Expiration

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 9. Trial Expiration
- **Requirement:** Notify users before expiration. Never surprise them.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-010 — Upgrade Screen

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 10. Upgrade Screen
- **Requirement:** Beautiful premium page. Contains: Plans Comparison Benefits Pricing FAQ Restore Purchases
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-011 — Plan Comparison

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 11. Plan Comparison
- **Requirement:** Table showing: Feature Free Plus Pro Family Coach Clinic
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-012 — Locked Features

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 12. Locked Features
- **Requirement:** When a premium feature is opened: Explain: Why it's premium. What it does. How to upgrade. Never show an error.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-013 — Feature Entitlements

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 13. Feature Entitlements
- **Requirement:** Every feature checks: Entitlement. Not subscription name. Allows future flexibility.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-014 — Restore Purchases

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 14. Restore Purchases
- **Requirement:** Available everywhere. One tap.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-015 — Subscription Management

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 15. Subscription Management
- **Requirement:** Show: Current plan Renewal date Expiration Auto-renew Manage Cancel
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-016 — Grace Period

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 16. Grace Period
- **Requirement:** Support temporary payment failures. User informed clearly.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-017 — Billing Retry

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 17. Billing Retry
- **Requirement:** Automatic retry. Transparent status.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-018 — Purchase History

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 18. Purchase History
- **Requirement:** Show: Invoices Payments Renewals Refunds
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-019 — Refund Support

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 19. Refund Support
- **Requirement:** Platform compliant. Never fake refunds.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-020 — Payment Providers

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 20. Payment Providers
- **Requirement:** Support: Apple Google Stripe PayPal Regional gateways
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-021 — Apple

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 21. Apple
- **Requirement:** StoreKit. Subscriptions. Offer Codes. Restore.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-022 — Google

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 22. Google
- **Requirement:** Play Billing. Subscriptions. Base Plans. Offers.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-023 — Web

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 23. Web
- **Requirement:** Stripe. PayPal. Apple Pay. Google Pay.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-024 — Regional Payments

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 24. Regional Payments
- **Requirement:** Support where available: Fawry Mada STC Pay CliQ Wallets Licensed providers.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-025 — Gift Codes

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 25. Gift Codes
- **Requirement:** Users redeem: Promo Codes Gift Codes Partner Codes
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-026 — Referral Program

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 26. Referral Program
- **Requirement:** Invite friends. Reward both sides. Prevent abuse.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-027 — Seasonal Campaigns

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 27. Seasonal Campaigns
- **Requirement:** Support: Ramadan Black Friday New Year Launch Campaigns
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-028 — Promotions

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 28. Promotions
- **Requirement:** Percentage. Fixed amount. Bundle. Limited time.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-029 — Eligibility Rules

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 29. Eligibility Rules
- **Requirement:** Promotion eligibility stored server-side. Not client-side.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-030 — Dynamic Pricing

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 30. Dynamic Pricing
- **Requirement:** Support: Regional strategy. Never hidden discrimination. Transparent.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-031 — Family Plan

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 31. Family Plan
- **Requirement:** Primary account. Invite members. Separate private health data. Shared billing only.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-032 — Coach Plan

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 32. Coach Plan
- **Requirement:** Professional tools unlocked.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-033 — Clinic Plan

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 33. Clinic Plan
- **Requirement:** Multiple professionals. Administration. Reporting.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-034 — Enterprise Ready

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 34. Enterprise Ready
- **Requirement:** Prepared for: Corporate wellness. Insurance. Healthcare.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-035 — Entitlement Server

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 35. Entitlement Server
- **Requirement:** Central authority. Never trust client purchase state.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-036 — Receipt Validation

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 36. Receipt Validation
- **Requirement:** Always server-side.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-037 — Webhooks

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 37. Webhooks
- **Requirement:** Handle: Purchase Renewal Cancellation Refund Expiration
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-038 — Offline Handling

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 38. Offline Handling
- **Requirement:** Temporary offline access allowed. Revalidated later.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-039 — Subscription Expired

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 39. Subscription Expired
- **Requirement:** User keeps: Own data. Export. History. Core functionality. Premium features gracefully lock.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-040 — No Hostage Data

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 40. No Hostage Data
- **Requirement:** Never prevent users from accessing their own historical information.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-041 — Usage Limits

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 41. Usage Limits
- **Requirement:** Support: AI credits. Coach sessions. Cloud quota. Community features. Export limits.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-042 — Upgrade Suggestions

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 42. Upgrade Suggestions
- **Requirement:** Appear naturally. Never interrupt workflows.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-043 — Revenue Analytics

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 43. Revenue Analytics
- **Requirement:** Track: Conversions. Renewals. Churn. Trials. Without exposing personal health data.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-044 — Compliance

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 44. Compliance
- **Requirement:** Respect: Apple policies. Google Play policies. Consumer protection laws. Tax requirements.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-045 — Security

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 45. Security
- **Requirement:** No card data stored in BIL. Payments handled by licensed providers.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-046 — Fraud Protection

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 46. Fraud Protection
- **Requirement:** Server validation. Rate limits. Abuse detection. Duplicate purchase prevention.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-047 — Cancellation

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 47. Cancellation
- **Requirement:** Simple. Transparent. No hidden steps.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-048 — Future Marketplace

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 48. Future Marketplace
- **Requirement:** Prepared for: Coach marketplace. Meal plans. Premium templates. Digital products.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-049 — Scalability

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 49. Scalability
- **Requirement:** Commerce architecture supports millions of subscriptions without redesign.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

### BIL-COM-050 — Final Commerce Principle

- **Source section:** Part 1 — Payments, Subscriptions, Entitlements & Revenue Platform / 50. Final Commerce Principle
- **Requirement:** Users should subscribe because BIL continually delivers clear value—not because core functionality is crippled or because the app pressures them into paying. Global Launch Package
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `docs/COMMERCIAL_BOUNDARY.md`; `lib/app/environment`; future entitlement service and store adapters
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Store/provider sandbox, server receipt, entitlement, restore, grace, refund, fraud, webhook, regional-policy, and offline tests.
- **Blocker:** Requires registered store products/accounts, server-side receipt and entitlement infrastructure, payment credentials, webhooks, fraud controls, and current regional policy review.
- **Completion commit:** —

## Part 1 — Worldwide Product Launch & Growth Strategy

### BIL-GRO-001 — Mission

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 1. Mission
- **Requirement:** The Global Launch Package transforms BIL from a completed application into a successful global product. Building the app is only the first step. Getting millions of people to trust and use it is the real objective.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-002 — Launch Philosophy

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 2. Launch Philosophy
- **Requirement:** Never launch because the app is finished. Launch because the experience is exceptional.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-003 — Launch Stages

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 3. Launch Stages
- **Requirement:** Stage 1 Private Alpha Stage 2 Closed Beta Stage 3 Open Beta Stage 4 Official Launch Stage 5 Global Expansion
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-004 — Alpha Goals

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 4. Alpha Goals
- **Requirement:** Invite only. Find bugs. Measure stability. Collect feedback. No marketing.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-005 — Closed Beta

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 5. Closed Beta
- **Requirement:** Limited users. Real-world testing. Crash reports. Retention. Performance.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-006 — Open Beta

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 6. Open Beta
- **Requirement:** Public access. Monitor servers. Improve onboarding. Collect reviews.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-007 — Official Launch

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 7. Official Launch
- **Requirement:** Launch only when: Crash-free rate exceeds target. Performance is stable. Payments verified. Cloud verified. AI verified. Localization complete.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-008 — Global Availability

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 8. Global Availability
- **Requirement:** Support: Android iPhone iPad Windows Web Future: macOS Wearables
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-009 — Languages

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 9. Languages
- **Requirement:** Launch with: English Arabic Then expand.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-010 — Country Expansion

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 10. Country Expansion
- **Requirement:** Priority: USA Canada UK Australia Germany France Saudi Arabia UAE Jordan Egypt Then additional markets.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-011 — Localization

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 11. Localization
- **Requirement:** Translate: Application Website Emails Help Center Store listings Push notifications
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-012 — Regional Content

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 12. Regional Content
- **Requirement:** Adapt: Units Currency Food databases Date formats Payment methods
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-013 — Website

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 13. Website
- **Requirement:** Professional landing page. Fast. Responsive. SEO optimized.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-014 — Marketing Website

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 14. Marketing Website
- **Requirement:** Include: Features Screenshots Pricing FAQ Testimonials Download links
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-015 — Blog

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 15. Blog
- **Requirement:** Publish: Nutrition articles. Progress stories. Product updates. Research.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-016 — Email System

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 16. Email System
- **Requirement:** Welcome. Verification. Password reset. Weekly summaries. Release notes.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-017 — Push Notifications

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 17. Push Notifications
- **Requirement:** Useful only. Never spam.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-018 — Social Media

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 18. Social Media
- **Requirement:** Official presence on: X Instagram Facebook LinkedIn YouTube TikTok
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-019 — Community

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 19. Community
- **Requirement:** Official Discord. Official Reddit. Future forum.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-020 — Influencer Strategy

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 20. Influencer Strategy
- **Requirement:** Work with: Nutrition coaches. Fitness creators. Doctors (verified). Scientists.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-021 — Referral Program

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 21. Referral Program
- **Requirement:** Reward users. No fake growth.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-022 — Ambassador Program

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 22. Ambassador Program
- **Requirement:** Top users become ambassadors.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-023 — Reviews

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 23. Reviews
- **Requirement:** Ask only after positive experiences. Never on first launch.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-024 — App Store Assets

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 24. App Store Assets
- **Requirement:** Professional: Icons Screenshots Videos Descriptions Keywords
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-025 — Press Kit

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 25. Press Kit
- **Requirement:** Prepare: Logos. Brand guide. Screenshots. Founder story. Media assets.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-026 — Analytics

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 26. Analytics
- **Requirement:** Track: Retention. DAU. MAU. Subscriptions. Engagement.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-027 — Crash Monitoring

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 27. Crash Monitoring
- **Requirement:** Target: 99.9% crash-free sessions.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-028 — Performance Monitoring

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 28. Performance Monitoring
- **Requirement:** Startup time. Search latency. Sync time. AI response time.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-029 — User Feedback

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 29. User Feedback
- **Requirement:** In-app feedback. Feature requests. Bug reporting. Voting.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-030 — Public Roadmap

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 30. Public Roadmap
- **Requirement:** Transparent roadmap. Users know what's coming.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-031 — Changelog

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 31. Changelog
- **Requirement:** Every update explains: New. Improved. Fixed.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-032 — Customer Support

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 32. Customer Support
- **Requirement:** Email. Knowledge base. AI assistant. Future live chat.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-033 — Trust

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 33. Trust
- **Requirement:** Show: Privacy. Security. Scientific approach.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-034 — Legal

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 34. Legal
- **Requirement:** Prepare: Privacy Policy. Terms. Cookie Policy. Health disclaimer.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-035 — Accessibility

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 35. Accessibility
- **Requirement:** WCAG support. Screen readers. Keyboard. Large fonts.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-036 — Data Protection

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 36. Data Protection
- **Requirement:** GDPR. CCPA. Regional compliance.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-037 — Growth Metrics

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 37. Growth Metrics
- **Requirement:** Measure: Activation. Retention. Conversion. Referral. Churn.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-038 — Product Metrics

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 38. Product Metrics
- **Requirement:** Daily check-ins. Meal logging. Food search. Water tracking. Body Twin usage. AI usage.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-039 — Brand Voice

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 39. Brand Voice
- **Requirement:** Professional. Friendly. Scientific. Respectful. Never sensational.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-040 — Partnerships

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 40. Partnerships
- **Requirement:** Nutrition organizations. Fitness companies. Clinics. Universities.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-041 — Expansion

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 41. Expansion
- **Requirement:** Future integrations: Apple Health Google Health Connect Wearables Smart scales Fitness trackers
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-042 — Business Continuity

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 42. Business Continuity
- **Requirement:** Backups. Monitoring. Incident response. Disaster recovery.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-043 — Release Cadence

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 43. Release Cadence
- **Requirement:** Bug fixes: As needed. Features: Planned releases. Major versions: Well documented.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-044 — Beta Program

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 44. Beta Program
- **Requirement:** Separate testing channel. Early adopters. Feedback collection.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-045 — Enterprise Readiness

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 45. Enterprise Readiness
- **Requirement:** Prepared for: Companies. Hospitals. Universities. Insurance.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-046 — International Scaling

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 46. International Scaling
- **Requirement:** Cloud regions. Regional pricing. Regional compliance. Localized support.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-047 — Brand Promise

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 47. Brand Promise
- **Requirement:** BIL helps users understand their bodies. Not fear them.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-048 — Competitive Position

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 48. Competitive Position
- **Requirement:** Never compete only on: Features. Compete on: Trust. Intelligence. Speed. Design. Privacy.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-049 — Long-Term Goal

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 49. Long-Term Goal
- **Requirement:** Become the world's most trusted body intelligence platform. Not merely another calorie tracker.
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

### BIL-GRO-050 — Final Launch Principle

- **Source section:** Part 1 — Worldwide Product Launch & Growth Strategy / 50. Final Launch Principle
- **Requirement:** A successful launch is not measured by downloads on day one. It is measured by how many users still open BIL every morning one year later because it has become an essential part of understanding and improving their health. App Store Release Package
- **Current repository status:** `strategic/non-code`
- **Files/modules involved:** `README.md`; `docs/CHANGELOG.md`; `docs/platform_support.md`; external launch/support/marketing systems
- **Acceptance criteria:** A named product owner approves a dated decision/evidence record and future implementation continues to conform without contradictory UI or claims.
- **Tests required:** Launch checklist evidence, localization review, support/incident drills, analytics consent validation, and external-channel acceptance.
- **Blocker:** Product/operations decision rather than a code completion gate.
- **Completion commit:** —

## Part 1 — Store Readiness, Publishing & Production Release

### BIL-REL-001 — Mission

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 1. Mission
- **Requirement:** The App Store Release Package ensures BIL can be published professionally on every supported platform with the highest possible quality, compliance, security, and presentation.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-002 — Supported Platforms

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 2. Supported Platforms
- **Requirement:** Official launch targets: Android (Google Play) iPhone (App Store) iPad Windows Web (PWA) Future: macOS WearOS watchOS
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-003 — Release Philosophy

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 3. Release Philosophy
- **Requirement:** Never publish because development is finished. Publish only when: Stable Fast Beautiful Trusted Fully tested
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-004 — Versioning

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 4. Versioning
- **Requirement:** Semantic Versioning: Major.Minor.Patch Examples: 1.0.0 1.1.0 1.1.3 2.0.0
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-005 — Release Branch

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 5. Release Branch
- **Requirement:** Every production release comes from: release/x.x.x Never from development branches.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-006 — Git Tags

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 6. Git Tags
- **Requirement:** Every production release receives: Git Tag Release Notes Build Number Commit Hash
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-007 — Android Release

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 7. Android Release
- **Requirement:** Produce: APK (testing) AAB (Google Play) Signed Release.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-008 — iOS Release

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 8. iOS Release
- **Requirement:** Produce: Archive TestFlight Build App Store Release
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-009 — Windows Release

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 9. Windows Release
- **Requirement:** Produce: Signed Installer Portable Version Release ZIP
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-010 — Web Release

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 10. Web Release
- **Requirement:** Generate: Optimized Build PWA Compression Caching Version Detection
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-011 — Application Icons

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 11. Application Icons
- **Requirement:** Prepare: Android iOS Windows Web Adaptive Icons Dark Variants
- **Current repository status:** `complete`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** `7879f48`

### BIL-REL-012 — Splash Screens

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 12. Splash Screens
- **Requirement:** Native. Fast. Premium. Consistent branding.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-013 — Store Screenshots

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 13. Store Screenshots
- **Requirement:** Prepare screenshots for: Phone Tablet Desktop Dark Theme Light Theme Arabic English
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-014 — Promotional Video

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 14. Promotional Video
- **Requirement:** 30–60 seconds. Professional. Real application. No fake UI.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-015 — Feature Graphics

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 15. Feature Graphics
- **Requirement:** Google Play: Feature Graphic Promo Banner
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-016 — App Preview

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 16. App Preview
- **Requirement:** Apple App Store: Official Preview Video.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-017 — Store Description

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 17. Store Description
- **Requirement:** Write: Short Description Full Description Keywords Highlights
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-018 — Localization

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 18. Localization
- **Requirement:** Translate: Store descriptions Screenshots Release notes Privacy pages
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-019 — Privacy Policy

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 19. Privacy Policy
- **Requirement:** Hosted online. Always updated.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-020 — Terms of Service

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 20. Terms of Service
- **Requirement:** Legally reviewed. Easy to read.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-021 — Health Disclaimer

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 21. Health Disclaimer
- **Requirement:** Visible. Localized. Scientifically accurate.
- **Current repository status:** `complete`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** `49b0fa8`

### BIL-REL-022 — App Permissions

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 22. App Permissions
- **Requirement:** Request only when needed. Explain clearly.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-023 — Sensitive Permissions

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 23. Sensitive Permissions
- **Requirement:** Camera Notifications Storage Location Requested only when actually required.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-024 — Crash-Free Target

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 24. Crash-Free Target
- **Requirement:** Production target: 99.9%
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-025 — Startup Target

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 25. Startup Target
- **Requirement:** Cold Start: As fast as technically possible. No blank white screens.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-026 — Performance Target

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 26. Performance Target
- **Requirement:** Food Search Body Twin Dashboard Weight Logging Should feel instant.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-027 — Accessibility

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 27. Accessibility
- **Requirement:** Screen Reader Large Text Keyboard Navigation High Contrast Reduced Motion
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-028 — Offline Verification

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 28. Offline Verification
- **Requirement:** Application must work without Internet. Cloud sync resumes later.
- **Current repository status:** `complete`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** `49b0fa8`

### BIL-REL-029 — Security Review

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 29. Security Review
- **Requirement:** Before every release: Secrets API Keys Permissions Certificates Dependencies
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-030 — Dependency Audit

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 30. Dependency Audit
- **Requirement:** Remove: Unused packages Deprecated packages Unsafe packages
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-031 — Static Analysis

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 31. Static Analysis
- **Requirement:** Must pass: flutter analyze Without errors.
- **Current repository status:** `complete`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** `5acc9cc`

### BIL-REL-032 — Tests

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 32. Tests
- **Requirement:** Required: Unit Widget Integration Regression End-to-End
- **Current repository status:** `complete`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** `5acc9cc`

### BIL-REL-033 — Manual QA

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 33. Manual QA
- **Requirement:** Verify: Registration Login Weight Meals Water Dashboard AI Payments Coach Sync Community
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-034 — Device Testing

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 34. Device Testing
- **Requirement:** Phones Tablets Desktop Web Different screen sizes.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-035 — Supported OS

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 35. Supported OS
- **Requirement:** Android: Document supported API levels. iOS: Document minimum version. Windows: Document supported versions.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-036 — Release Notes

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 36. Release Notes
- **Requirement:** Every version explains: New Features Improvements Bug Fixes Performance Known Issues
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-037 — Rollout Strategy

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 37. Rollout Strategy
- **Requirement:** Internal Alpha Beta Staged Rollout 100% Release
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-038 — Rollback Strategy

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 38. Rollback Strategy
- **Requirement:** Every release can be rolled back safely.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-039 — Monitoring

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 39. Monitoring
- **Requirement:** Immediately after release monitor: Crash Rate Startup Payments Sync AI Servers
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-040 — Incident Response

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 40. Incident Response
- **Requirement:** Critical bug? Hotfix process documented.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-041 — Store Ratings

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 41. Store Ratings
- **Requirement:** Prompt only after: Positive engagement. Never on first launch.
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-042 — Support Center

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 42. Support Center
- **Requirement:** Users can access: FAQ Help Bug Reports Contact Support
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-043 — Analytics Review

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 43. Analytics Review
- **Requirement:** Measure: Downloads Retention Engagement Conversion Churn
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-044 — Security Updates

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 44. Security Updates
- **Requirement:** Critical fixes released immediately.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-045 — Long-Term Maintenance

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 45. Long-Term Maintenance
- **Requirement:** Monthly: Dependency updates Security patches Performance improvements
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-046 — Production Checklist

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 46. Production Checklist
- **Requirement:** Every release verifies: Analyze Tests Builds Signing Localization Accessibility Privacy Store assets Documentation
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-047 — Launch Approval

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 47. Launch Approval
- **Requirement:** No production release without passing: Technical Review UX Review Security Review Performance Review
- **Current repository status:** `blocked by credentials/infrastructure`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Activate only after the blocker is supplied and the complete production adapter, authorization, privacy, failure, deletion/export, monitoring, and end-to-end acceptance suite passes; until then the UI remains disabled and honest.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** Requires owned application identifiers/store records, signing credentials, store assets/metadata, supported host hardware, physical devices, legal approval, and release operations.
- **Completion commit:** —

### BIL-REL-048 — Success Criteria

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 48. Success Criteria
- **Requirement:** A successful release is one that users do not notice technically. Everything simply works.
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-049 — Continuous Improvement

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 49. Continuous Improvement
- **Requirement:** Every release should improve: Speed Trust Intelligence Design Reliability
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

### BIL-REL-050 — Final Release Principle

- **Source section:** Part 1 — Store Readiness, Publishing & Production Release / 50. Final Release Principle
- **Requirement:** Publishing BIL is not the finish line. It is the beginning of a long-term commitment to continuously improving the most trusted body intelligence platform in the world. Enterprise Architecture
- **Current repository status:** `partial`
- **Files/modules involved:** `pubspec.yaml`; `android`; `ios`; `windows`; `web`; `assets`; `docs/IOS_READINESS.md`; `docs/platform_support.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Analyze, full tests, platform builds, signing/store validation, device QA, accessibility, security, offline, rollback, and staged rollout checks.
- **Blocker:** None
- **Completion commit:** —

## Part 1 — Long-Term Scalable Technical Architecture

### BIL-ARC-001 — Mission

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 1. Mission
- **Requirement:** The architecture must support growth from: One user to Millions of users without requiring a complete rewrite.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-002 — Core Philosophy

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 2. Core Philosophy
- **Requirement:** One Product One Codebase One Business Logic Multiple Platforms
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-003 — Technology Stack

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 3. Technology Stack
- **Requirement:** Frontend Flutter Backend Supabase (initially) Future-ready for custom services.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** `99037c7`

### BIL-ARC-004 — Clean Architecture

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 4. Clean Architecture
- **Requirement:** Layers: Presentation Application Domain Infrastructure Platform
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-005 — Domain First

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 5. Domain First
- **Requirement:** Business rules never depend on: Flutter Supabase SQLite AI Provider Payment Provider Cloud Provider
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-006 — Modular Structure

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 6. Modular Structure
- **Requirement:** Modules: Authentication Profile Diary Food Weight Analytics Body Twin Truth Engine Coach Community Commerce AI Settings Admin
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-007 — Feature Independence

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 7. Feature Independence
- **Requirement:** Each module should compile independently. Dependencies only through interfaces.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-008 — Shared Design System

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 8. Shared Design System
- **Requirement:** Single Design System. Shared Components. Never duplicate UI.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-009 — Shared Business Engine

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 9. Shared Business Engine
- **Requirement:** One deterministic engine. Never separate Android logic from iOS logic.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** `1e34961`

### BIL-ARC-010 — Dependency Injection

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 10. Dependency Injection
- **Requirement:** All services resolved through DI. No global singletons where avoidable.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** `49b0fa8`

### BIL-ARC-011 — Repository Pattern

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 11. Repository Pattern
- **Requirement:** Repositories abstract: Database Cloud AI Payments Storage
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** `84e5633`

### BIL-ARC-012 — Platform Adapters

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 12. Platform Adapters
- **Requirement:** Separate: Android iOS Windows Web Future macOS
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-013 — No Platform Checks Everywhere

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 13. No Platform Checks Everywhere
- **Requirement:** Avoid: Platform.isAndroid kIsWeb Inside business logic. Use adapters.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-014 — Database Layer

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 14. Database Layer
- **Requirement:** Repository ↓ Data Source Drift SQLite/Web implementation
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** `84e5633`

### BIL-ARC-015 — Cloud Layer

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 15. Cloud Layer
- **Requirement:** Cloud interface only. Provider replaceable.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-016 — AI Layer

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 16. AI Layer
- **Requirement:** Provider abstraction. Support: OpenAI Gemini Anthropic Future local LLMs.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-017 — Commerce Layer

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 17. Commerce Layer
- **Requirement:** Unified Entitlement Engine. Separate payment providers.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-018 — Authentication Layer

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 18. Authentication Layer
- **Requirement:** Replaceable providers. Never tightly coupled.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-019 — Notification Layer

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 19. Notification Layer
- **Requirement:** Abstract notifications. Platform implementations hidden.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-020 — Storage Layer

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 20. Storage Layer
- **Requirement:** Abstract: Files Images Exports Cloud objects
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-021 — Configuration

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 21. Configuration
- **Requirement:** Central configuration service. No hardcoded values.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-022 — Feature Flags

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 22. Feature Flags
- **Requirement:** All major features controllable remotely.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-023 — Environment Profiles

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 23. Environment Profiles
- **Requirement:** Development Testing Staging Production
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-024 — Secrets

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 24. Secrets
- **Requirement:** Never committed. Never inside application source.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** `12187e1`

### BIL-ARC-025 — Logging

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 25. Logging
- **Requirement:** Structured logging. Sensitive data removed.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-026 — Error Handling

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 26. Error Handling
- **Requirement:** Unified. Meaningful. Recoverable.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-027 — Analytics

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 27. Analytics
- **Requirement:** Independent service. Replaceable.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-028 — Crash Reporting

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 28. Crash Reporting
- **Requirement:** Independent. Privacy aware.
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-029 — State Management

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 29. State Management
- **Requirement:** Riverpod remains source of truth. Avoid multiple state systems.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** `49b0fa8`

### BIL-ARC-030 — Routing

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 30. Routing
- **Requirement:** Single routing architecture. Deep linking ready.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** `49b0fa8`

### BIL-ARC-031 — Localization

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 31. Localization
- **Requirement:** Independent module. Scalable.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-032 — Assets

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 32. Assets
- **Requirement:** Centralized. Versioned. Optimized.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-033 — Testing Strategy

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 33. Testing Strategy
- **Requirement:** Unit Widget Integration Golden E2E Performance
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** `5acc9cc`

### BIL-ARC-034 — Continuous Integration

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 34. Continuous Integration
- **Requirement:** Automatic: Analyze Test Build Artifacts
- **Current repository status:** `missing and locally implementable`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-035 — Continuous Delivery

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 35. Continuous Delivery
- **Requirement:** Staged deployment. Rollback ready.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-036 — Security

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 36. Security
- **Requirement:** Defense in depth. Least privilege. Encryption.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-037 — Scalability

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 37. Scalability
- **Requirement:** Prepared for: 10 users 100 1,000 100,000 1,000,000+
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-038 — Observability

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 38. Observability
- **Requirement:** Metrics. Tracing. Logging. Alerts.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-039 — Documentation

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 39. Documentation
- **Requirement:** Every module documented. Architecture diagrams maintained.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** `99037c7`

### BIL-ARC-040 — API Design

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 40. API Design
- **Requirement:** Versioned. Backward compatible. Documented.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-041 — Performance

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 41. Performance
- **Requirement:** Performance budgets defined. Measured continuously.
- **Current repository status:** `complete`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** All source clauses are represented by the cited repository implementation/evidence, remain localized where user-facing, use real local data, and pass the listed regression coverage.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** `fcab54e`

### BIL-ARC-042 — Maintainability

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 42. Maintainability
- **Requirement:** Readable code. Small modules. Low coupling. High cohesion.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-043 — Extensibility

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 43. Extensibility
- **Requirement:** Every future feature should plug into the architecture. Not modify its foundations.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-044 — Upgrade Strategy

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 44. Upgrade Strategy
- **Requirement:** Dependencies updated regularly. Breaking changes isolated.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-045 — Technical Debt

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 45. Technical Debt
- **Requirement:** Tracked. Prioritized. Reduced continuously.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-046 — Code Reviews

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 46. Code Reviews
- **Requirement:** Every major feature reviewed before merge.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-047 — Release Governance

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 47. Release Governance
- **Requirement:** No production deployment without: Tests Security review Performance review
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-048 — Disaster Recovery

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 48. Disaster Recovery
- **Requirement:** Backups. Rollback. Recovery plans.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-049 — Long-Term Vision

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 49. Long-Term Vision
- **Requirement:** The architecture should still feel modern five years after the first release.
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

### BIL-ARC-050 — Final Architecture Principle

- **Source section:** Part 1 — Long-Term Scalable Technical Architecture / 50. Final Architecture Principle
- **Requirement:** The architecture of BIL should be almost invisible to users. They should only notice that the application is fast, reliable, secure, beautiful, and consistently works the same across every device they own. END
- **Current repository status:** `partial`
- **Files/modules involved:** `lib/app`; `lib/data`; `lib/engine`; `lib/features`; `lib/shared`; `docs/ARCHITECTURE.md`
- **Acceptance criteria:** Implement every source clause end-to-end with real persisted data, bilingual/RTL UI, accessible and responsive states, honest empty/loading/error behavior, and no simulated external success.
- **Tests required:** Architecture dependency tests, unit/widget/integration/golden/E2E suites, performance budgets, CI builds, and security review.
- **Blocker:** None
- **Completion commit:** —

