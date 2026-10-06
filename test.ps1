# End-to-end smoke test for auth-api + data-api (PowerShell 5.1+ / 7+).
# Usage (from repo root, after `docker compose up -d --build`):
#   powershell -ExecutionPolicy Bypass -File .\test.ps1
param(
    [string]$AuthUrl = "http://localhost:8080",
    [string]$DataUrl = "http://localhost:8081",
    [string]$InternalToken = "dev-internal-token-change-me",
    [string]$DbUser = "app",
    [string]$DbName = "appdb"
)

Set-Location $PSScriptRoot
$script:failed = 0

function Call([string]$Method, [string]$Url, $Body = $null, [hashtable]$Headers = @{}) {
    $p = @{ Method = $Method; Uri = $Url; Headers = $Headers; UseBasicParsing = $true }
    if ($null -ne $Body) {
        $p.Body = ($Body | ConvertTo-Json -Compress)
        $p.ContentType = "application/json"
    }
    $status = 0
    $content = $null
    try {
        $r = Invoke-WebRequest @p
        $status = [int]$r.StatusCode
        $content = $r.Content
    } catch {
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    }
    $json = $null
    if ($content) { try { $json = $content | ConvertFrom-Json } catch {} }
    return [pscustomobject]@{ Status = $status; Json = $json }
}

function Check([string]$Name, [bool]$Ok, [string]$Detail = "") {
    if ($Ok) {
        Write-Host ("[PASS] " + $Name) -ForegroundColor Green
    } else {
        Write-Host ("[FAIL] " + $Name + "  " + $Detail) -ForegroundColor Red
        $script:failed++
    }
}

$email = "test_" + (Get-Random) + "@example.com"
$creds = @{ email = $email; password = "pass" }
$text  = @{ text = "hello" }

# --- auth-api ---
$r = Call POST "$AuthUrl/api/auth/register" $creds
if ($r.Status -eq 0) {
    Write-Host "Cannot reach $AuthUrl. Is 'docker compose up -d --build' running?" -ForegroundColor Red
    exit 1
}
Check "register -> 201" ($r.Status -eq 201) "got $($r.Status)"

$r = Call POST "$AuthUrl/api/auth/register" $creds
Check "duplicate register -> 409" ($r.Status -eq 409) "got $($r.Status)"

$r = Call POST "$AuthUrl/api/auth/login" @{ email = $email; password = "wrong-password" }
Check "login with wrong password -> 401" ($r.Status -eq 401) "got $($r.Status)"

$r = Call POST "$AuthUrl/api/auth/login" $creds
$token = $null
if ($r.Json) { $token = $r.Json.token }
Check "login -> 200 + token" (($r.Status -eq 200) -and [bool]$token) "got $($r.Status)"

# --- /api/process ---
$r = Call POST "$AuthUrl/api/process" $text @{ Authorization = "Bearer $token" }
$res = $null
if ($r.Json) { $res = $r.Json.result }
Check "process with token -> 200, result OLLEH" (($r.Status -eq 200) -and ($res -eq "OLLEH")) "got $($r.Status) / $res"

$r = Call POST "$AuthUrl/api/process" $text
Check "process without token -> 401" ($r.Status -eq 401) "got $($r.Status)"

$r = Call POST "$AuthUrl/api/process" $text @{ Authorization = "Bearer not.a.jwt" }
Check "process with invalid token -> 401" ($r.Status -eq 401) "got $($r.Status)"

# --- data-api ---
$r = Call POST "$DataUrl/api/transform" $text
Check "data-api without internal token -> 403" ($r.Status -eq 403) "got $($r.Status)"

$r = Call POST "$DataUrl/api/transform" $text @{ "X-Internal-Token" = "wrong" }
Check "data-api with wrong internal token -> 403" ($r.Status -eq 403) "got $($r.Status)"

$r = Call POST "$DataUrl/api/transform" $text @{ "X-Internal-Token" = $InternalToken }
$res = $null
if ($r.Json) { $res = $r.Json.result }
Check "data-api with internal token -> 200, result OLLEH" (($r.Status -eq 200) -and ($res -eq "OLLEH")) "got $($r.Status) / $res"

# --- database ---
$sql = "select count(*) from processing_log p join users u on u.id = p.user_id where u.email = '$email' and p.input_text = 'hello' and p.output_text = 'OLLEH'"
$count = ("" + (docker compose exec -T postgres psql -U $DbUser -d $DbName -t -A -c $sql)).Trim()
Check "processing_log row saved for this user" ($count -eq "1") "count = '$count'"

Write-Host ""
if ($script:failed -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
}
Write-Host "$($script:failed) check(s) failed." -ForegroundColor Red
exit 1
