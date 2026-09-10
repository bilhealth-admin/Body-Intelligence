# Pure row validation only: no device, image, network or filesystem operations.
function Test-BilWebcamResultContract {
    param([object[]]$Rows, [object[]]$Cases)
    if ($Rows.Count -ne 31 -or $Cases.Count -ne 31) { return $false }
    $expected = @{}
    foreach ($case in $Cases) {
        if ($expected.ContainsKey([string]$case.case_id)) { return $false }
        $expected[[string]$case.case_id] = [string]$case.category
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($row in $Rows) {
        if (-not $seen.Add([string]$row.case_id) -or
            -not $expected.ContainsKey([string]$row.case_id) -or
            $row.category -cne $expected[[string]$row.case_id] -or
            $row.success -cne 'PASS' -or
            $row.camera_input_source -cne 'android_emulator_host_webcam0') { return $false }
        foreach ($field in @('timestamp_utc','recognized_item','food_nonfood','barcode_result','evidence_file')) {
            if ([string]::IsNullOrWhiteSpace([string]$row.$field)) { return $false }
        }
        foreach ($field in @('input_tokens','output_tokens','latency_ms','cost_usd','quota_consumed')) {
            $number = 0.0
            if (-not [double]::TryParse([string]$row.$field,
                [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture,
                [ref]$number) -or [double]::IsNaN($number) -or
                [double]::IsInfinity($number) -or $number -lt 0) { return $false }
            if ($field -in @('input_tokens','output_tokens','latency_ms') -and
                $number -ne [math]::Truncate($number)) { return $false }
        }
        if ($row.gemini_fallback -cnotin @('true','false') -or
            $row.dedup_prevented -cnotin @('true','false') -or
            $row.cache_hit -cnotin @('true','false','n/a')) { return $false }
        if ($row.gemini_fallback -ceq 'true' -and
            ([string]::IsNullOrWhiteSpace([string]$row.model) -or $row.model -ceq 'n/a')) { return $false }
    }
    return $true
}
