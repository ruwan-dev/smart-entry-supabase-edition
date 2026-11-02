# Smart Entry Pre-Commit QA Runner Script
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      SMART ENTRY PRE-COMMIT QA TEST RUNNER         " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$hasBlockingError = $false

# 1. Automated Tests & Multi-Tenant Scanner
Write-Host "`n[1/3] Running Automated Tests & Tenant Isolation Scanner..." -ForegroundColor Yellow
flutter.bat test
if ($LASTEXITCODE -ne 0) {
    Write-Host " [FAIL] One or more automated tests failed!" -ForegroundColor Red
    $hasBlockingError = $true
} else {
    Write-Host " [PASS] All automated tests passed successfully." -ForegroundColor Green
}

# 2. Static Analysis & Compiler Health Check
Write-Host "`n[2/3] Running Dart Static Analysis..." -ForegroundColor Yellow
$dartExe = if (Test-Path "C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe") { "C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe" } else { "dart" }
$analysisRaw = & $dartExe analyze lib test 2>&1
$errorLines = $analysisRaw | Where-Object { $_ -match "^\s*error\s+-" }
$warningLines = $analysisRaw | Where-Object { $_ -match "^\s*warning\s+-" }

if ($errorLines) {
    Write-Host " [FAIL] Compile errors found!" -ForegroundColor Red
    $errorLines | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
    $hasBlockingError = $true
} else {
    Write-Host " [PASS] Zero compile errors." -ForegroundColor Green
    if ($warningLines) {
        Write-Host " [INFO] $($warningLines.Count) non-blocking warning(s) detected:" -ForegroundColor Yellow
        $warningLines | Select-Object -First 5 | ForEach-Object { Write-Host "   $_" -ForegroundColor Yellow }
    }
}

# 3. Code Cleanliness & Tenant Guideline Check
Write-Host "`n[3/3] Checking Code Cleanliness in lib/..." -ForegroundColor Yellow
$sinhalaInComments = Select-String -Path "lib\*.dart", "lib\**\*.dart" -Pattern "//.*[\u0D80-\u0DFF]"
if ($sinhalaInComments) {
    Write-Host " [WARN] Found Sinhala inside code comments in lib/:" -ForegroundColor Yellow
    $sinhalaInComments | ForEach-Object { Write-Host "   $($_.Path):$($_.LineNumber)" }
} else {
    Write-Host " [PASS] English code comments verified." -ForegroundColor Green
}

Write-Host "`n====================================================" -ForegroundColor Cyan
if ($hasBlockingError) {
    Write-Host "  RESULT: FAILED - DO NOT MERGE! Fix errors above.   " -ForegroundColor Red
    exit 1
} else {
    Write-Host "  RESULT: PASSED - CODE IS READY TO MERGE!           " -ForegroundColor Green
    exit 0
}
