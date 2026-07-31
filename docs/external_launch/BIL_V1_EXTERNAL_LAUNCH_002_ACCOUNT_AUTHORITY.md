# External Launch 002 — Legal Owner and Developer Account Authority

## Executive boundary

This package prepares Gate 2 for one controlled external action. It does not
enroll in, pay for, log in to, or accept agreements for Google Play Console or
the Apple Developer Program.

## Required ownership decision

The same release owner should control both developer accounts unless a legally
documented organization will own the product. The enrollment type must be one
of:

- `individual` — the store seller identity is the enrolling legal person.
- `organization` — the seller is a registered legal entity and the enrolling
  person has authority to bind it.

Do not select `organization` without actual entity documentation and authority.
Do not use nicknames, invented business names, borrowed identities, or account
credentials belonging to another person.

## Google Play evidence required

- Enrollment type and legal owner name.
- Country/region selected during enrollment.
- Active Google Play Console developer account.
- Registration payment receipt or transaction reference.
- Identity-verification state.
- Public developer name recorded separately from the legal owner.
- Account identifier recorded without passwords, recovery codes, or tokens.

## Apple evidence required

- Enrollment type and legal owner name.
- Country/region and billing identity.
- Apple Developer Program membership state.
- Membership payment receipt or order reference.
- Team ID when Apple issues it.
- Account Holder authority.
- Agreement status recorded without passwords, 2FA codes, certificates, or
  private keys.

## Evidence location

Create the completed evidence only at:

`.bil-package-evidence/external_launch/account_authority_evidence.json`

The file is outside Git. The tracked JSON template contains placeholders only.

## Gate decision

Gate 2 remains `BLOCKED_EXTERNAL` until the verifier confirms actual account
authority evidence for both Google and Apple. Preparation of this package is
not completion evidence.
