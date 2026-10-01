# BIL historical credential exposure follow-up

The final release certification secret scan found credential-bearing Git remote
examples in a tracked historical message ledger. The current release source
redacts those lines and does not rely on embedded repository credentials.

Because the value existed in Git history, source cleanup alone is not evidence
of revocation. Before the independent security gate can be called PASS, the
repository owner must verify that any credential represented by those historical
remote URLs is revoked or rotated. No credential value is reproduced here.

The Firebase Android API key in `android/app/google-services.json` is retained
as publishable client configuration and is reported separately by the repository
inventory; other Google API-key matches remain security candidates.
