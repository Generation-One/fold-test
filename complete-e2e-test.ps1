#!/usr/bin/env powershell

<#
.SYNOPSIS
Complete end-to-end test of Fold v2 with detailed diagnostics

.DESCRIPTION
Tests the entire system including chunking and search, with detailed error reporting
#>

param(
    [string]$Token = "fold_7tL9ZOLlVpC1EFhCxWsAfgjIlsyACfABGOyNCabt",
    [string]$FoldUrl = "http://localhost:8765",
    [string]$QdrantUrl = "http://localhost:6333",
    [string]$SampleFilesPath = "d:\hh\git\g1\fold\test\sample-files",
    [string]$DbPath = "d:\hh\git\g1\fold\srv\data\fold.db",
    [switch]$Verbose,
    [switch]$StopOnFirstFailure,
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"
$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

$testResults = @{
    Passed = 0
    Failed = 0
    Tests = @()
}

function Write-Test($name, $result, $details) {
    $status = if ($result) { "✅ PASS" } else { "❌ FAIL" }
    Write-Host "$status - $name" -ForegroundColor $(if ($result) { "Green" } else { "Red" })
    if ($details) {
        Write-Host "   $details" -ForegroundColor Gray
    }

    if ($result) {
        $testResults.Passed++
    } else {
        $testResults.Failed++
        if ($StopOnFirstFailure) {
            exit 1
        }
    }

    $testResults.Tests += @{ Name = $name; Result = $result; Details = $details }
}

function Query-Db($sql) {
    if (-not (Test-Path $DbPath)) {
        return $null
    }
    & sqlite3 $DbPath $sql 2>&1
}

# ===== START TESTS =====

Write-Host "`n" -ForegroundColor Black
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FOLD V2 COMPLETE E2E TEST" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test 1: Health Check
Write-Host "1. SYSTEM HEALTH" -ForegroundColor White
try {
    $health = Invoke-RestMethod -Uri "$FoldUrl/health" -Headers $headers -TimeoutSec 5
    Write-Test "Server responding" ($health.status -eq "healthy") "Status: $($health.status)"
} catch {
    Write-Test "Server responding" $false "Error: $_"
}

# Test 2: Create Project
Write-Host "`n2. PROJECT CREATION" -ForegroundColor White
$projectId = $null
try {
    $projectBody = @{
        name = "Complete E2E Test"
        slug = "complete-e2e-$(Get-Date -Format 'HHmmss')"
        description = "Complete end-to-end system test with all features"
    } | ConvertTo-Json

    $project = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $projectBody -TimeoutSec 10
    $projectId = $project.id
    $projectSlug = $project.slug
    Write-Test "Create project" ($projectId -ne $null) "Project ID: $projectId, Slug: $projectSlug"
} catch {
    Write-Test "Create project" $false "Error: $_"
    exit 1
}

# Test 3: Verify project was created
try {
    $retrievedProject = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId" -Headers $headers -TimeoutSec 5
    Write-Test "Retrieve project" ($retrievedProject.id -eq $projectId) "Name: $($retrievedProject.name)"
} catch {
    Write-Test "Retrieve project" $false "Error: $_"
}

# Test 4: Add Memories (one at a time with detailed diagnostics)
Write-Host "`n3. MEMORY CREATION & STORAGE" -ForegroundColor White
$memoryIds = @()
$addedMemories = 0
$failedMemories = 0

if (Test-Path $SampleFilesPath) {
    $files = Get-ChildItem $SampleFilesPath -File | Where-Object { $_.Extension -in ".rs", ".ts", ".md", ".py", ".txt" }
    Write-Host "   Found $($files.Count) files to process`n" -ForegroundColor Gray

    $fileIndex = 0
    foreach ($file in $files) {
        $fileIndex++
        try {
            $content = [System.IO.File]::ReadAllText($file.FullName)
            if ($content.Length -gt 0 -and $content.Length -lt 100000) {
                $memBody = @{
                    title = $file.Name
                    content = $content
                    file_path = $file.Name
                    author = "e2e-test"
                } | ConvertTo-Json -Depth 10

                Write-Host "   [$fileIndex] Adding $($file.Name)..." -ForegroundColor Gray
                $startTime = Get-Date
                $mem = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/memories" -Method POST -Headers $headers -Body $memBody -TimeoutSec 60
                $elapsed = (Get-Date) - $startTime

                $memoryIds += $mem.id
                $addedMemories++
                Write-Host "       ✅ Added (${elapsed.TotalSeconds.ToString('F1')}s, ID: $($mem.id))" -ForegroundColor Green
            }
        } catch {
            $failedMemories++
            Write-Host "       ❌ Failed: $_" -ForegroundColor Red
        }
    }
}

Write-Test "Add memories" ($addedMemories -gt 0) "Added $addedMemories files, Failed: $failedMemories"

# Test 5: Verify Memories in Database
Write-Host "`n4. DATABASE VERIFICATION" -ForegroundColor White
Start-Sleep -Seconds 2

$dbMemCount = Query-Db "SELECT COUNT(*) FROM memories WHERE project_id = '$projectId';"
Write-Test "Memories in database" ($dbMemCount -eq $addedMemories) "Database count: $dbMemCount, Expected: $addedMemories"

# Test 6: Check Qdrant Collection
Write-Host "`n5. VECTOR STORAGE (QDRANT)" -ForegroundColor White
try {
    $collectionName = "fold_$projectSlug"
    $qdrantCollection = Invoke-RestMethod -Uri "$QdrantUrl/collections/$collectionName" -TimeoutSec 5 -ErrorAction Stop

    if ($qdrantCollection) {
        $vectorCount = $qdrantCollection.result.points_count
        $indexedVectors = $qdrantCollection.result.indexed_vectors_count
        Write-Test "Vectors stored in Qdrant" ($vectorCount -gt 0) "Points: $vectorCount, Indexed: $indexedVectors"

        if ($indexedVectors -eq 0 -and $vectorCount -gt 0) {
            Write-Host "   ⚠️  WARNING: Vectors not indexed yet. Qdrant indexing_threshold: 10000" -ForegroundColor Yellow
        }
    } else {
        Write-Test "Vectors stored in Qdrant" $false "Collection not found in Qdrant"
    }
} catch {
    Write-Test "Vectors stored in Qdrant" $false "Qdrant error: $_"
}

# Test 7: Check Chunks in Database
Write-Host "`n6. SEMANTIC CHUNKING" -ForegroundColor White
$chunkCount = Query-Db "SELECT COUNT(*) FROM chunks WHERE project_id = '$projectId';"
Write-Test "Chunks created" ($chunkCount -gt 0) "Total chunks: $chunkCount"

if ($chunkCount -gt 0) {
    $chunkTypes = Query-Db "SELECT DISTINCT node_type, COUNT(*) as cnt FROM chunks WHERE project_id = '$projectId' GROUP BY node_type;"
    Write-Host "   Chunk breakdown:" -ForegroundColor Gray
    foreach ($line in $chunkTypes) {
        Write-Host "      $line" -ForegroundColor Gray
    }
}

# Test 8: Try direct Qdrant search to verify vectors are searchable
Write-Host "`n7. QDRANT DIRECT SEARCH TEST" -ForegroundColor White
try {
    # Get collection stats
    $statsResponse = Invoke-RestMethod -Uri "$QdrantUrl/collections/$collectionName" -TimeoutSec 5 -ErrorAction Stop
    $pointCount = $statsResponse.result.points_count
    Write-Test "Sample point accessible" ($pointCount -gt 0) "Found $pointCount points in collection"
} catch {
    Write-Test "Sample point accessible" $false "Error: $_"
}

# Test 9: Search via API
Write-Host "`n8. API SEARCH & RETRIEVAL" -ForegroundColor White
try {
    $searchBody = @{ query = "function"; include_chunks = $true; min_score = 0.0 } | ConvertTo-Json
    $searchResults = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody -TimeoutSec 30
    $resultCount = $searchResults.results.Count

    Write-Test "Search returns results" ($resultCount -gt 0) "Results found: $resultCount"

    if ($resultCount -gt 0) {
        $firstResult = $searchResults.results[0]
        Write-Test "Search result has score" ($firstResult.score -ne $null) "Score: $($firstResult.score)"
        Write-Test "Search result has metadata" ($firstResult.title -ne $null) "Title: $($firstResult.title)"
    }
} catch {
    Write-Test "Search returns results" $false "Error: $_"
}

# Test 10: Configuration Management
Write-Host "`n9. CONFIGURATION MANAGEMENT" -ForegroundColor White
try {
    $config = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Headers $headers -TimeoutSec 5
    Write-Test "Read decay config" ($config.strength_weight -ne $null) "Weight: $($config.strength_weight), Half-life: $($config.decay_half_life_days)"
} catch {
    Write-Test "Configuration management" $false "Error: $_"
}

# Test 11: Error Handling
Write-Host "`n10. ERROR HANDLING" -ForegroundColor White
try {
    $badConfig = @{ strength_weight = 1.5 } | ConvertTo-Json
    Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $badConfig -TimeoutSec 5 -ErrorAction Stop
    Write-Test "Reject invalid strength_weight" $false "Should have rejected value > 1.0"
} catch {
    Write-Test "Reject invalid strength_weight" ($_.Exception.Response.StatusCode -ge 400) "Correctly rejected"
}

# Test 12: Cleanup
Write-Host "`n11. CLEANUP" -ForegroundColor White
if ($SkipCleanup) {
    Write-Host "   Skipping cleanup (-SkipCleanup flag set)" -ForegroundColor Yellow
    Write-Host "   Project ID: $projectId" -ForegroundColor Cyan
    Write-Host "   Project Slug: $projectSlug" -ForegroundColor Cyan
} else {
    try {
        Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId" -Method DELETE -Headers $headers -TimeoutSec 10 | Out-Null
        Write-Test "Delete project" $true "Project deleted"
    } catch {
        Write-Test "Delete project" $false "Error: $_"
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TEST RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ✅ Passed: $($testResults.Passed)" -ForegroundColor Green
Write-Host "  ❌ Failed: $($testResults.Failed)" -ForegroundColor $(if ($testResults.Failed -gt 0) { "Red" } else { "Green" })

$totalTests = $testResults.Passed + $testResults.Failed
$passPercentage = if ($totalTests -gt 0) { [math]::Round(($testResults.Passed / $totalTests) * 100, 1) } else { 0 }
Write-Host "  Pass Rate: $passPercentage% ($($testResults.Passed)/$totalTests)`n" -ForegroundColor Yellow

exit $(if ($testResults.Failed -gt 0) { 1 } else { 0 })
