Write-Host "===============================================" -ForegroundColor Cyan
Write-Host " Building Smart Entry v1.0.1 Installer" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# 1. Build Flutter Windows Release
Write-Host "`n[1/3] Compiling Flutter Windows Release binaries..." -ForegroundColor Yellow
$flutterBin = "C:\src\flutter\bin\flutter.bat"
if (-not (Test-Path $flutterBin)) {
    $flutterCmd = Get-Command flutter.bat -ErrorAction SilentlyContinue
    if ($flutterCmd) { $flutterBin = $flutterCmd.Source }
}

& $flutterBin build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[ERROR] Flutter build failed!" -ForegroundColor Red
    exit 1
}

# 2. Compile Inno Setup Script
Write-Host "`n[2/3] Compiling Inno Setup Installer..." -ForegroundColor Yellow
$isccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $isccPath)) {
    $isccPath = "C:\Program Files\Inno Setup 6\ISCC.exe"
}

if (Test-Path $isccPath) {
    & $isccPath smart_entry_installer.iss
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[ERROR] Inno Setup compilation failed!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n[ERROR] Inno Setup compiler (ISCC.exe) not found at: $isccPath" -ForegroundColor Red
    exit 1
}

# 3. Success Summary
Write-Host "`n===============================================" -ForegroundColor Green
Write-Host " [SUCCESS] Installer Generated Successfully!" -ForegroundColor Green
Write-Host " File: Installer\SmartEntry_Setup_v1.0.1.exe" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
