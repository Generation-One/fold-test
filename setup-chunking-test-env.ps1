#!/usr/bin/env powershell

# Setup Clean Testing Environment for Chunking Validation
# This script creates a project with sample files, indexes them, and verifies chunk relationships

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
Write-Host "  CHUNKING TEST ENVIRONMENT SETUP" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Create project
Write-Host "Step 1: Creating project..." -ForegroundColor White

$projectBody = @{
    name = "Sample Files Test Project"
    slug = "sample-files-test-$(Get-Date -Format 'HHmmss')"
    description = "Testing chunking with sample code files"
    root_path = $SampleFilesPath
} | ConvertTo-Json

try {
    $project = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $projectBody
    $projectId = $project.id
    Write-Host "✅ Project created: $projectId" -ForegroundColor Green
    Write-Host "   Name: $($project.name)" -ForegroundColor Gray
    Write-Host "   Slug: $($project.slug)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Failed to create project: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Add memory files from sample-files directory
Write-Host "`nStep 2: Adding memories from sample files..." -ForegroundColor White

if (-not (Test-Path $SampleFilesPath)) {
    Write-Host "❌ Sample files path not found: $SampleFilesPath" -ForegroundColor Red
    exit 1
}

$fileCount = 0
$memoryIds = @()

Get-ChildItem -Path $SampleFilesPath -File -Recurse | ForEach-Object {
    $filePath = $_.FullName
    $relativePath = $filePath.Substring($SampleFilesPath.Length + 1)

    try {
        $content = Get-Content -Path $filePath -Raw -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Host "   Skipping empty file: $relativePath" -ForegroundColor Gray
            return
        }

        $memBody = @{
            title = $_.Name
            content = $content
            file_path = $relativePath
            author = "test-setup"
        } | ConvertTo-Json -Depth 10

        $mem = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/memories" -Method POST -Headers $headers -Body $memBody
        $memoryIds += $mem.id
        $fileCount++

        Write-Host "   ✅ $relativePath" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Failed to add $relativePath : $_" -ForegroundColor Red
    }
}

Write-Host "`n✅ Added $fileCount memories" -ForegroundColor Green

# Step 3: Wait for indexing
Write-Host "`nStep 3: Waiting for indexing to complete..." -ForegroundColor White
Start-Sleep -Seconds 5
Write-Host "✅ Indexing wait complete" -ForegroundColor Green

# Step 4: Query database to verify chunks
Write-Host "`nStep 4: Verifying chunks in database..." -ForegroundColor White

function Invoke-SQLiteQuery {
    param(
        [string]$Query,
        [string]$DbPath = "d:\hh\git\g1\fold\fold.db"
    )

    $result = & sqlite3 $DbPath $Query 2>&1
    return $result
}

# Verify chunks were created
$chunkQuery = "SELECT COUNT(*) FROM chunks WHERE project_id = '$projectId';"
$chunkCount = Invoke-SQLiteQuery -Query $chunkQuery
Write-Host "   Total chunks created: $chunkCount" -ForegroundColor Gray

if ([int]$chunkCount -gt 0) {
    Write-Host "✅ Chunks found" -ForegroundColor Green

    # Show chunk details
    $detailQuery = @"
SELECT
    c.id,
    c.node_type,
    c.node_name,
    COALESCE(c.start_line, 'N/A') as start_line,
    COALESCE(c.end_line, 'N/A') as end_line,
    LENGTH(c.content) as content_length,
    c.language
FROM chunks c
WHERE c.project_id = '$projectId'
LIMIT 10;
"@

    Write-Host "`n   Sample chunks:" -ForegroundColor Cyan
    $chunks = Invoke-SQLiteQuery -Query $detailQuery
    $chunks | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ No chunks found" -ForegroundColor Red
}

# Verify memories have parent_memory_id relationships
Write-Host "`n   Checking parent_memory_id relationships..." -ForegroundColor Cyan
$parentQuery = @"
SELECT
    COUNT(DISTINCT parent_memory_id) as unique_parents,
    COUNT(*) as total_chunks_with_parent
FROM chunks
WHERE project_id = '$projectId' AND parent_memory_id IS NOT NULL;
"@

$parentResult = Invoke-SQLiteQuery -Query $parentQuery
Write-Host "   $parentResult" -ForegroundColor Gray

# Verify language detection
Write-Host "`n   Language detection:" -ForegroundColor Cyan
$langQuery = "SELECT language, COUNT(*) as count FROM chunks WHERE project_id = '$projectId' GROUP BY language;"
$langResult = Invoke-SQLiteQuery -Query $langQuery
if ($langResult) {
    $langResult | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
} else {
    Write-Host "   (No language information)" -ForegroundColor Gray
}

# Verify memories exist
Write-Host "`nStep 5: Verifying memories..." -ForegroundColor White
$memQuery = "SELECT COUNT(*) FROM memories WHERE project_id = '$projectId';"
$memCount = Invoke-SQLiteQuery -Query $memQuery
Write-Host "   Total memories: $memCount" -ForegroundColor Gray

if ([int]$memCount -eq $fileCount) {
    Write-Host "✅ All memories stored" -ForegroundColor Green
} else {
    Write-Host "⚠️ Memory count mismatch: created $fileCount, found $memCount" -ForegroundColor Yellow
}

# Step 6: Test search to verify vectors were created
Write-Host "`nStep 6: Testing search to verify vectorization..." -ForegroundColor White

$searchQueries = @(
    @{ query = "function"; label = "function keyword" },
    @{ query = "authentication"; label = "authentication" },
    @{ query = "import"; label = "import statement" }
)

foreach ($search in $searchQueries) {
    $searchBody = @{ query = $search.query } | ConvertTo-Json
    try {
        $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody
        $resultCount = $result.results.Count

        if ($resultCount -gt 0) {
            Write-Host "   ✅ Search '$($search.label)': found $resultCount results" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️ Search '$($search.label)': no results" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ❌ Search '$($search.label)' failed: $_" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TEST ENVIRONMENT SETUP COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nProject Details:" -ForegroundColor White
Write-Host "  Project ID: $projectId" -ForegroundColor Gray
Write-Host "  Memories: $memCount" -ForegroundColor Gray
Write-Host "  Chunks: $chunkCount" -ForegroundColor Gray
Write-Host "`nProject Endpoint:" -ForegroundColor White
Write-Host "  $FoldUrl/projects/$projectId" -ForegroundColor Gray
Write-Host "`n"
