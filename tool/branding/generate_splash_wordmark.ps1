param()

$ErrorActionPreference = 'Stop'

# RETIRED, FAIL CLOSED: this historical generator produced the superseded
# 864x864 identity. It must never overwrite the owner-approved 1080x1080
# release source or its native byte-identical derivatives. Verification lives
# in tool/epic15_store_asset_audit.dart and pins the authoritative SHA-256.
throw @'
RETIRED: splash identity generation is disabled. Preserve the owner-approved
assets/branding/bil_splash_identity.png and validate it with
dart run tool/epic15_store_asset_audit.dart.
'@
