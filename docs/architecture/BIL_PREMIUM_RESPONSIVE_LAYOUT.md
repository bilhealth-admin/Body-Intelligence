# BIL Premium Responsive Layout

## Parent baseline

`9b3f7086f9478c82ad2b578cd391dec56ab69b87`

## Decision

`BilPremiumResponsiveLayout` owns the dashboard breakpoints, section rhythm,
text-scaled twin height, and paired-section height. The accepted values are
preserved while removing responsive policy from individual widget branches.

This package does not change content, decisions, navigation, localization, or
data. It creates one testable boundary for later phone, tablet, desktop, RTL,
and large-text refinement.
