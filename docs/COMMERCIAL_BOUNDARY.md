# Future commercial boundary

The MVP has no purchases and defaults to free local functionality. Widgets must
eventually query an entitlement provider instead of hard-coding premium checks.

The replaceable domain boundary should model product plan, feature entitlement,
subscription status, trial and promotional eligibility, purchase source,
restoration, grace period, billing retry, renewal, and cancellation. Candidate
plans are Free, Plus, Pro, Family, Coach/Professional, and—only where store
policy permits—Lifetime.

Authoritative entitlements must be verified server-side. Store credentials and
private billing keys must never ship in the app. External payment channels must
follow Apple App Store and Google Play policies applicable at implementation
time; those policies must be rechecked before commerce work begins.
