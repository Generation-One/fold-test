#!/usr/bin/env powershell

# Verify Chunking Setup - Uses SQL only for verification (not setup)

param(
    [string]$ProjectId = "987435f4-0328-476b-aa97-78e577b10f2a",
    [string]$DbPath = "d:\hh\git\g1\fold\fold.db"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CHUNKING VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

function Query-Db {
    param([string]$Query)
    & sqlite3 $DbPath $Query 2>&1
}

Write-Host "Project ID: $ProjectId`n" -ForegroundColor White

# Check if tables exist
Write-Host "Checking database..." -ForegroundColor White

$tableCheck = Query-Db ".tables"
if (-not $tableCheck) {
    Write-Host "❌ Database appears empty (no tables)" -ForegroundColor Red
    Write-Host "This may indicate the database was cleared or server is using a different one.`n" -ForegroundColor Yellow
    exit 1
}

# Count memories
Write-Host "Querying memories..." -ForegroundColor White
$memCount = Query-Db "SELECT COUNT(*) FROM memories WHERE project_id = '$ProjectId';"
Write-Host "  Memories: $memCount" -ForegroundColor Gray

if ($memCount -eq 0) {
    Write-Host "  ⚠️ No memories found in this project`n" -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Found $memCount memories`n" -ForegroundColor Green
}

# Count chunks
Write-Host "Querying chunks..." -ForegroundColor White
$chunkCount = Query-Db "SELECT COUNT(*) FROM chunks WHERE project_id = '$ProjectId';"
Write-Host "  Chunks: $chunkCount" -ForegroundColor Gray

if ($chunkCount -eq 0) {
    Write-Host "  ⚠️ No chunks found (chunking may not have completed yet)`n" -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Found $chunkCount chunks`n" -ForegroundColor Green

    # Show chunk breakdown
    Write-Host "Chunk breakdown by type:" -ForegroundColor Cyan
    $typeQuery = "SELECT node_type, COUNT(*) as count FROM chunks WHERE project_id = '$ProjectId' GROUP BY node_type ORDER BY count DESC;"
    Query-Db $typeQuery | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

    Write-Host "`nLanguage breakdown:" -ForegroundColor Cyan
    $langQuery = "SELECT language, COUNT(*) as count FROM chunks WHERE project_id = '$ProjectId' GROUP BY language ORDER BY count DESC;"
    Query-Db $langQuery | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

    # Show parent relationships
    Write-Host "`nParent memory relationships:" -ForegroundColor Cyan
    $parentQuery = "SELECT COUNT(DISTINCT parent_memory_id) as unique_parents FROM chunks WHERE project_id = '$ProjectId' AND parent_memory_id IS NOT NULL;"
    $parentCount = Query-Db $parentQuery
    Write-Host "  Unique parent memories: $parentCount" -ForegroundColor Gray

    # Show sample chunks
    Write-Host "`nSample chunks (limit 5):" -ForegroundColor Cyan
    $sampleQuery = "SELECT node_type, node_name, COALESCE(start_line, 'N/A') as line_start, COALESCE(end_line, 'N/A') as line_end, language FROM chunks WHERE project_id = '$ProjectId' LIMIT 5;"
    Query-Db $sampleQuery | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ Verification Complete" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
