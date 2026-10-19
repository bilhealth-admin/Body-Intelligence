param(
  [ValidateSet('create','cleanup')][string]$Mode,
  [Parameter(Mandatory=$true)][string]$StatePath
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'auth_admin_user_create.ps1')
$project='tgmanzhqulksykhslrzb'
$base="https://$project.supabase.co"
if (-not $env:RUNNER_TEMP -or -not $env:GITHUB_ENV) { throw 'GitHub ephemeral runner required' }
$stateFile=[IO.Path]::GetFullPath($StatePath)
$runnerRoot=[IO.Path]::GetFullPath($env:RUNNER_TEMP)+[IO.Path]::DirectorySeparatorChar
if (-not $stateFile.StartsWith($runnerRoot,[StringComparison]::Ordinal)) { throw 'Fixture state must stay in runner temp' }
$keys=((& npx --yes supabase@2.121.0 projects api-keys --project-ref $project --reveal --output json 2>$null)-join "`n")|ConvertFrom-Json
if($LASTEXITCODE -ne 0){throw 'Fixture server credentials unavailable'}
$service=($keys|Where-Object {$_.name -eq 'service_role'}|Select-Object -First 1).api_key
$public=($keys|Where-Object {$_.type -eq 'publishable'}|Select-Object -First 1).api_key
if(-not $service -or -not $public){throw 'Fixture credential types unavailable'}
$headers=@{apikey=$service;Authorization="Bearer $service"}
$fetchUsersPage = ({
  param($page, $perPage)
  Invoke-RestMethod -Uri "$base/auth/v1/admin/users?page=$page&per_page=$perPage" -Headers $headers
}).GetNewClosure()
try {
  if($Mode -eq 'cleanup') {
    if(-not (Test-Path -LiteralPath $stateFile)){Write-Output 'No disposable accounts were created';exit 0}
    $state=Get-Content -LiteralPath $stateFile -Raw|ConvertFrom-Json
    if($state.project -ne $project -or $state.run_id -ne $env:GITHUB_RUN_ID){throw 'Fixture provenance mismatch'}
    foreach($user in $state.users) {
      if($user.email -notmatch '^bil-native-[a-f0-9]{32}-[ab]@bilhealth\.invalid$'){throw 'Not a disposable fixture identity'}
      $userId=[string]$user.id
      if([string]::IsNullOrWhiteSpace($userId)) {
        # Recover a user whose create call timed out before its ID was saved.
        $pending=Find-BilAuthAdminUserByEmail -Email $user.email -FetchPage $fetchUsersPage
        if(-not $pending){continue}
        $userId=[string]$pending.id
      }
      if($userId -notmatch '^[a-f0-9-]{36}$'){throw 'Not a disposable fixture identity'}
      try { $readback=Invoke-RestMethod -Uri "$base/auth/v1/admin/users/$userId" -Headers $headers }
      catch {
        if($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404){continue}
        throw
      }
      if($readback.email -ne $user.email){throw 'Live identity differs; deletion refused'}
      [void](Invoke-RestMethod -Method Delete -Uri "$base/auth/v1/admin/users/$userId" -Headers $headers)
    }
    Remove-Item -LiteralPath $stateFile
    Write-Output 'Disposable native QA accounts deleted'
    exit 0
  }
  if(Test-Path -LiteralPath $stateFile){throw 'Existing fixture state must be cleaned first'}
  $state=@{project=$project;run_id=$env:GITHUB_RUN_ID;users=@()}
  $suffix=[guid]::NewGuid().ToString('N')
  foreach($name in @('a','b')) {
    $email="bil-native-$suffix-$name@bilhealth.invalid"
    $password="Bil!$([guid]::NewGuid().ToString('N'))A9"
    Write-Output "::add-mask::$email"
    Write-Output "::add-mask::$password"
    $state.users+=@{id='';email=$email}
    $state|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $stateFile -Encoding utf8
    $createBody=@{email=$email;password=$password;email_confirm=$true}|ConvertTo-Json
    $createRequest=({
      Invoke-RestMethod -Method Post -Uri "$base/auth/v1/admin/users" -Headers $headers -ContentType application/json -Body $createBody
    }).GetNewClosure()
    $findCreatedUser=({
      Find-BilAuthAdminUserByEmail -Email $email -FetchPage $fetchUsersPage
    }).GetNewClosure()
    $created=Invoke-BilAuthAdminUserCreateWithRecovery -CreateRequest $createRequest -FindUser $findCreatedUser
    $state.users[-1].id=[string]$created.id
    $state|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $stateFile -Encoding utf8
    $label=$name.ToUpperInvariant()
    Add-Content -LiteralPath $env:GITHUB_ENV -Value "BIL_EPIC9_ACCOUNT_${label}_EMAIL=$email"
    Add-Content -LiteralPath $env:GITHUB_ENV -Value "BIL_EPIC9_ACCOUNT_${label}_PASSWORD=$password"
    if($name -eq 'a') {
      Add-Content -LiteralPath $env:GITHUB_ENV -Value "BIL_BARCODE_GATE_EMAIL=$email"
      Add-Content -LiteralPath $env:GITHUB_ENV -Value "BIL_BARCODE_GATE_PASSWORD=$password"
      $uid=[string]$created.id
      $sql="insert into public.bil_entitlements(owner_id,entitlement_id,product_id,provider,active,starts_at,expires_at,source_transaction_id) values ('$uid','plan:premium','e2e-only','google',true,now(),now()+interval '1 hour','native-e2e-$suffix')"
      $old=$ErrorActionPreference;$ErrorActionPreference='Continue'
      try{$sql|& npx --yes supabase@2.121.0 db query --linked --project-ref $project --output json 2>$null|Out-Null;$queryExit=$LASTEXITCODE}finally{$ErrorActionPreference=$old}
      if($queryExit -ne 0){throw 'Synthetic one-hour barcode entitlement failed'}
    }
  }
  Add-Content -LiteralPath $env:GITHUB_ENV -Value "SUPABASE_URL=$base"
  Add-Content -LiteralPath $env:GITHUB_ENV -Value "SUPABASE_ANON_KEY=$public"
  Write-Output 'Two disposable non-admin accounts prepared; synthetic entitlement is not store-purchase proof'
} finally {
  Remove-Variable service,keys,password -ErrorAction SilentlyContinue
}
