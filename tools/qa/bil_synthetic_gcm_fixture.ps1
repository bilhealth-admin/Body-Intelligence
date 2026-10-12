param([ValidateSet('encrypt','decrypt')][string]$Mode)
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
# Public deterministic test key; NEVER a user/account key or a production cipher.
[byte[]]$testKey = 0..31
function Encode-Url([byte[]]$bytes) {
  [Convert]::ToBase64String($bytes).Replace('+','-').Replace('/','_')
}
function Decode-Url([string]$value) {
  [Convert]::FromBase64String($value.Replace('-','+').Replace('_','/'))
}
$inputText = [Console]::In.ReadToEnd()
$cipher = [System.Security.Cryptography.AesGcm]::new($testKey,16)
try {
  if ($Mode -eq 'encrypt') {
    [byte[]]$plain = [Text.Encoding]::UTF8.GetBytes($inputText)
    [byte[]]$nonce = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(12)
    [byte[]]$encrypted = [byte[]]::new($plain.Length)
    [byte[]]$tag = [byte[]]::new(16)
    $cipher.Encrypt($nonce,$plain,$encrypted,$tag)
    @{_bil_cipher_v=1;alg='A256GCM';nonce=(Encode-Url $nonce);ciphertext=(Encode-Url ([byte[]]($encrypted+$tag)))} | ConvertTo-Json -Compress
  } else {
    $envelope = $inputText | ConvertFrom-Json
    if ($envelope._bil_cipher_v -ne 1 -or $envelope.alg -ne 'A256GCM') {throw 'Unsupported synthetic cipher'}
    [byte[]]$nonce = Decode-Url $envelope.nonce
    [byte[]]$sealed = Decode-Url $envelope.ciphertext
    [byte[]]$encrypted = $sealed[0..($sealed.Length-17)]
    [byte[]]$tag = $sealed[($sealed.Length-16)..($sealed.Length-1)]
    [byte[]]$plain = [byte[]]::new($encrypted.Length)
    $cipher.Decrypt($nonce,$encrypted,$tag,$plain)
    [Text.Encoding]::UTF8.GetString($plain)
  }
} finally {$cipher.Dispose()}
