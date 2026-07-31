# BIL Next Packages

## Authoritative baseline

- Branch: `phase-3-product-excellence`
- HEAD: `ea024c85365ee2a14e8594231d6a14d941acd246`

## Current authorization state

No implementation package is currently authorized after BIL v1 program
closure. Architecture, Dashboard, Trusted Truth, and the cross-program closure
gates are complete and must not be listed as future work.

## Rule for opening the next package

The Product Owner must authorize a named post-program phase. Its first package
must declare:

- the accepted parent HEAD;
- a bounded repository scope;
- explicit exclusions and external gates;
- deterministic APPLY and VERIFY scripts;
- selective commit targets and an approval checkpoint.

Historical package candidates are records only. They are not authorization and
must not be replayed against the current baseline.
