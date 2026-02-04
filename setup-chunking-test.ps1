#!/usr/bin/env powershell

# Clean Chunking Test Setup - Uses API endpoints for all setup, SQL only for verification

param(
    [string]$Token = "fold_7tL9ZOLlVpC1EFhCxWsAfgjIlsyACfABGOyNCabt",
    [string]$FoldUrl = "http://localhost:8765",
    [string]$SampleFilesPath = "d:\hh\git\g1\fold\test\sample-files"
)

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CHUNKING TEST SETUP" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Create project via API
Write-Host "Creating project..." -ForegroundColor White

$projectBody = @{
    name = "Sample Files Test"
    slug = "sample-files-$(Get-Date -Format 'HHmmss')"
    description = "Testing chunking with sample code files"
} | ConvertTo-Json

$project = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $projectBody
$projectId = $project.id

Write-Host "✅ Project: $projectId`n" -ForegroundColor Green

# Step 2: Add memories via API
Write-Host "Adding memories from sample files..." -ForegroundColor White

$fileCount = 0
Get-ChildItem -Path $SampleFilesPath -File -Recurse | ForEach-Object {
    $filePath = $_.FullName
    $relativePath = $filePath.Substring($SampleFilesPath.Length + 1)
    $content = Get-Content -Path $filePath -Raw

    if (-not [string]::IsNullOrWhiteSpace($content)) {
        $memBody = @{
            title = $_.Name
            content = $content
            file_path = $relativePath
        } | ConvertTo-Json -Depth 10

        $mem = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/memories" -Method POST -Headers $headers -Body $memBody
        $fileCount++
        Write-Host "  ✅ $relativePath" -ForegroundColor Green
    }
}

Write-Host "`n✅ Added $fileCount memories`n" -ForegroundColor Green

# Step 3: Wait for indexing
Write-Host "Waiting for indexing..." -ForegroundColor White
Start-Sleep -Seconds 5
Write-Host "✅ Complete`n" -ForegroundColor Green

# Step 4: Verify via SQL
Write-Host "Verifying in database..." -ForegroundColor White

function Query-Db {
    param([string]$Query)
    & sqlite3 "d:\hh\git\g1\fold\fold.db" $Query 2>&1
}

$chunkCount = Query-Db "SELECT COUNT(*) FROM chunks WHERE project_id = '$projectId';"
$memCount = Query-Db "SELECT COUNT(*) FROM memories WHERE project_id = '$projectId';"

Write-Host "  Memories: $memCount" -ForegroundColor Gray
Write-Host "  Chunks: $chunkCount" -ForegroundColor Gray

if ($chunkCount -gt 0) {
    Write-Host "  ✅ Chunking successful`n" -ForegroundColor Green

    $langQuery = "SELECT language, COUNT(*) FROM chunks WHERE project_id = '$projectId' GROUP BY language;"
    Write-Host "  Language breakdown:" -ForegroundColor Cyan
    Query-Db $langQuery | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
} else {
    Write-Host "  ⚠️ No chunks found`n" -ForegroundColor Yellow
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project ID: $projectId" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan
