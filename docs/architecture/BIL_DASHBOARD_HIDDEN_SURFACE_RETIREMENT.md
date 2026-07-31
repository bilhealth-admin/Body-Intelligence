# Dashboard hidden-surface retirement

Package `BIL-V1-DASHBOARD-008` retires three child trees that were permanently
wrapped in `Visibility(visible: false, maintainState: false)` inside
`DashboardGrid`:

- the duplicate water card;
- the duplicate meals timeline;
- the duplicate One Best Action response panel.

These trees had no reachable presentation path. Their standalone widgets,
repositories, engines, and tests remain available to their owning features.
The visible `PremiumDashboardBenchmark` remains the single authoritative
Dashboard action surface, including its truth explanation and decision
feedback. The visible hydration action continues through
`DashboardCommandCoordinator.addWater`.

Reintroducing any retired surface requires an explicit placement decision and
a reachable interaction contract; it must not be added back as invisible
Dashboard baggage.
