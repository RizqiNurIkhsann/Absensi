# PowerShell script to fix Windows build for Flutter with Firebase
# This script automates the CMake version fix for Firebase C++ SDK

Write-Host "=== Flutter Windows Build Fix Script ===" -ForegroundColor Cyan

# Step 1: Run flutter clean
Write-Host "`n[1/4] Running flutter clean..." -ForegroundColor Yellow
flutter clean

# Step 2: Run flutter build windows (will fail but extract Firebase SDK)
Write-Host "`n[2/4] Running flutter build windows to extract Firebase SDK..." -ForegroundColor Yellow
Write-Host "This will fail - that's expected. We'll fix it automatically." -ForegroundColor Gray
flutter build windows 2>&1 | Out-Null

# Step 3: Fix the Firebase SDK CMakeLists.txt
$firebaseCmakeFile = "build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt"

if (Test-Path $firebaseCmakeFile) {
    Write-Host "`n[3/4] Fixing Firebase SDK CMake version..." -ForegroundColor Yellow
    
    $content = Get-Content $firebaseCmakeFile -Raw
    $content = $content -replace 'cmake_minimum_required\(VERSION 3\.1\)', 'cmake_minimum_required(VERSION 3.5)'
    Set-Content -Path $firebaseCmakeFile -Value $content
    
    Write-Host "Fixed: Updated cmake_minimum_required from 3.1 to 3.5" -ForegroundColor Green
} else {
    Write-Host "ERROR: Firebase SDK not found at $firebaseCmakeFile" -ForegroundColor Red
    Write-Host "Make sure you have firebase_core in your pubspec.yaml" -ForegroundColor Red
    exit 1
}

# Step 4: Run flutter build windows again
Write-Host "`n[4/4] Running flutter build windows..." -ForegroundColor Yellow
flutter build windows

Write-Host "`n=== Done! ===" -ForegroundColor Cyan
