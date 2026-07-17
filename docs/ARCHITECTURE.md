# BIL – Body Intelligence Log

## Vision

BIL is not a calorie tracker.

BIL is an intelligent body assistant.

The user should never calculate calories, protein, fats, carbohydrates, TDEE or nutrition targets manually.

The user only provides:

- Daily weight
- Foods eaten

Everything else is calculated automatically by BIL.

---

# Core Philosophy

Track Less.
Understand More.

The application explains the body instead of asking the user to understand nutrition.

---

# Main Principles

1. UI never performs calculations.

2. All calculations belong to Engine.

3. Database only stores data.

4. Repository handles data access.

5. Providers connect UI with business logic.

6. Engine is Pure Dart.

7. Engine must never import:
    - Flutter
    - Riverpod
    - Drift
    - Supabase
    - Widgets

---

# Folder Structure

lib/

core/

engine/

data/

features/

services/

---

# Engine Layers

Calculation

Analysis

Prediction

Recommendation

Scoring

BIL Engine

---

# User Flow

First Launch

↓

Onboarding

↓

Dashboard

↓

Morning Weight

↓

Meals

↓

Daily Summary

↓

BIL Intelligence

---

# Long-term Goal

Build the smartest body assistant rather than another calorie tracker.