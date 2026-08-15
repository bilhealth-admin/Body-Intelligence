param(
  [switch]$Force
)

$ErrorActionPreference = "Stop"
$project = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$android = Join-Path $project "android"
$keyDir = Join-Path $android "keystores"
$keyPath = Join-Path $keyDir "bil-upload-key.jks"
$propertiesPath = Join-Path $android "key.properties"
$evidenceDir = Join-Path $project ".bil-package-evidence\signing"
$recoveryPath = Join-Path $evidenceDir "android-upload-key-recovery.txt"

if ((Test-Path -LiteralPath $keyPath) -and (Test-Path -LiteralPath $propertiesPath) -and -not $Force) {
  Write-Output "ANDROID_UPLOAD_KEY=EXISTS_NOT_OVERWRITTEN"
  Write-Output "KEYSTORE=$keyPath"
  Write-Output "PROPERTIES=$propertiesPath"
  exit 0
}

if ((Test-Path -LiteralPath $propertiesPath) -and -not (Test-Path -LiteralPath $keyPath)) {
  throw "Partial Android signing state detected: key.properties exists without its keystore. Restore the matching private keystore from backup; nothing was overwritten."
}

if ($Force) {
  throw "Refusing to overwrite an upload identity automatically. Move the existing private files manually after backing them up."
}

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if ($null -eq $keytool) {
  $studioKeytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
  if (Test-Path -LiteralPath $studioKeytool) {
    $keytoolPath = $studioKeytool
  } else {
    throw "keytool was not found. Install Android Studio/JDK 17 or newer."
  }
} else {
  $keytoolPath = $keytool.Source
}

New-Item -ItemType Directory -Force -Path $keyDir, $evidenceDir | Out-Null

# keytool writes normal progress messages to stderr. Windows PowerShell turns
# those messages into NativeCommandError records, and an earlier revision of
# this script could stop after keytool had already created the keystore but
# before key.properties was written. That orphaned keystore has an unrecoverable
# generated password, so preserve it as evidence and create a fresh matched pair.
if ((Test-Path -LiteralPath $keyPath) -and -not (Test-Path -LiteralPath $propertiesPath)) {
  $orphanStamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
  $orphanPath = Join-Path $evidenceDir "orphaned-bil-upload-key-$orphanStamp.jks"
  Move-Item -LiteralPath $keyPath -Destination $orphanPath
  Write-Output "ORPHANED_KEYSTORE=PRESERVED"
  Write-Output "ORPHANED_KEYSTORE_PATH=$orphanPath"
}

$randomBytes = New-Object byte[] 36
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
  $rng.GetBytes($randomBytes)
} finally {
  $rng.Dispose()
}
$password = [Convert]::ToBase64String($randomBytes).Replace('/', 'A').Replace('+', 'B').TrimEnd('=')
$alias = "bil-upload"

$previousErrorActionPreference = $ErrorActionPreference
try {
  # Capture stderr so keytool's successful progress text is emitted as ordinary
  # output instead of terminating the script as NativeCommandError.
  $ErrorActionPreference = "Continue"
  $keytoolOutput = & $keytoolPath -genkeypair -v `
    -keystore $keyPath `
    -storepass $password `
    -keypass $password `
    -alias $alias `
    -keyalg RSA `
    -keysize 4096 `
    -validity 10000 `
    -dname "CN=BIL Android Upload Key, OU=Release, O=BIL" 2>&1
  $keytoolExitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousErrorActionPreference
}

foreach ($line in $keytoolOutput) {
  Write-Output ($line.ToString())
}
if ($keytoolExitCode -ne 0) { throw "keytool failed: $keytoolExitCode" }

@(
  "storeFile=keystores/bil-upload-key.jks"
  "storePassword=$password"
  "keyAlias=$alias"
  "keyPassword=$password"
) | Set-Content -LiteralPath $propertiesPath -Encoding ascii

@(
  "BIL ANDROID UPLOAD KEY - PRIVATE RECOVERY RECORD"
  "CreatedUtc=$([DateTime]::UtcNow.ToString('o'))"
  "Keystore=$keyPath"
  "Alias=$alias"
  "Password=$password"
  ""
  "Back up this keystore and password offline. Losing the upload key may block future updates."
  "Never add this file, key.properties, or the keystore to Git."
) | Set-Content -LiteralPath $recoveryPath -Encoding utf8

Write-Output "ANDROID_UPLOAD_KEY=CREATED"
Write-Output "KEYSTORE=$keyPath"
Write-Output "RECOVERY_RECORD=$recoveryPath"
Write-Output "BACKUP_REQUIRED=True"
