param(
  [Parameter(Mandatory = $false)]
  [ValidatePattern('^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$')]
  [string] $VersionName = '1.0.0',

  [Parameter(Mandatory = $false)]
  [ValidateRange(1, 2100000000)]
  [int] $VersionCode = 1,

  [Parameter(Mandatory = $false)]
  [string[]] $DartDefine = @(),

  [Parameter(Mandatory = $false)]
  [string] $ArtifactPath = 'artifacts/release/app-release.aab',

  [Parameter(Mandatory = $false)]
  [switch] $PrepareOnly,

  [Parameter(Mandatory = $false)]
  [switch] $SkipPubGet
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

throw 'FINAL_PROOF_ANDROID_BUILD=HISTORICAL_NON_CANDIDATE. This local helper cannot establish the reviewed production defines or current signed release contract. Use .github/workflows/bil_android_release_candidate.yml. No artifact was produced.'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$registrant = Join-Path $repoRoot 'android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java'
$releaseAab = Join-Path $repoRoot 'build\app\outputs\bundle\release\app-release.aab'
$keyProperties = Join-Path $repoRoot 'android\key.properties'

function Remove-ReleaseOnlyIntegrationTestRegistration {
  param([Parameter(Mandatory = $true)][string] $Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Flutter did not generate the Android plugin registrant: $Path"
  }

  $source = [IO.File]::ReadAllText($Path)
  $pattern = '(?ms)^\s{4}try \{\r?\n\s{6}flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\r?\n\s{4}\} catch \(Exception e\) \{\r?\n\s{6}Log\.e\(TAG, "Error registering plugin integration_test, dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin", e\);\r?\n\s{4}\}\r?\n'
  $matches = [regex]::Matches($source, $pattern)
  if ($matches.Count -gt 1) {
    throw "Refusing to edit an unexpected registrant: found $($matches.Count) integration_test blocks."
  }

  if ($matches.Count -eq 1) {
    $source = [regex]::Replace($source, $pattern, '', 1)
    [IO.File]::WriteAllText($Path, $source, [Text.UTF8Encoding]::new($false))
  }

  $remaining = [IO.File]::ReadAllText($Path)
  if ($remaining.Contains('dev.flutter.plugins.integration_test.IntegrationTestPlugin')) {
    throw 'The dev-only integration_test plugin is still present in the release registrant.'
  }
  if (-not $remaining.Contains('io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin')) {
    throw 'The release registrant lost a required production plugin.'
  }
}

Push-Location $repoRoot
try {
  if (-not $SkipPubGet) {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed with exit code $LASTEXITCODE" }
  }

  Remove-ReleaseOnlyIntegrationTestRegistration -Path $registrant

  if ($PrepareOnly) {
    [pscustomobject]@{
      status = 'prepared'
      registrant = $registrant
      integration_test_removed = $true
    } | ConvertTo-Json -Compress
    exit 0
  }

  if (-not (Test-Path -LiteralPath $keyProperties)) {
    throw 'android/key.properties is missing. Keep signing material outside version control and restore it securely.'
  }

  $flutterArgs = @(
    'build', 'appbundle', '--release', '--no-pub',
    '--build-name', $VersionName,
    '--build-number', $VersionCode.ToString()
  )
  foreach ($define in $DartDefine) {
    if ([string]::IsNullOrWhiteSpace($define) -or -not $define.Contains('=')) {
      throw 'Each DartDefine must be a nonempty KEY=VALUE pair.'
    }
    $flutterArgs += "--dart-define=$define"
  }

  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) { throw "Flutter release build failed with exit code $LASTEXITCODE" }
  if (-not (Test-Path -LiteralPath $releaseAab)) { throw "Release AAB was not produced: $releaseAab" }

  $destination = if ([IO.Path]::IsPathRooted($ArtifactPath)) {
    [IO.Path]::GetFullPath($ArtifactPath)
  } else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $ArtifactPath))
  }
  $destinationDirectory = Split-Path -Parent $destination
  $null = New-Item -ItemType Directory -Path $destinationDirectory -Force
  Copy-Item -LiteralPath $releaseAab -Destination $destination -Force

  $artifact = Get-Item -LiteralPath $destination
  [pscustomobject]@{
    status = 'built'
    version_name = $VersionName
    version_code = $VersionCode
    artifact = $artifact.FullName
    bytes = $artifact.Length
    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifact.FullName).Hash
  } | ConvertTo-Json -Compress
} finally {
  Pop-Location
}
