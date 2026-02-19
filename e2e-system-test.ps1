#!/usr/bin/env powershell

<#
.SYNOPSIS
Fold v2 End-to-End System Test

.DESCRIPTION
Comprehensive test of the entire Fold v2 system:
- Project creation and management
- Memory creation and storage
- Semantic chunking
- Vector embeddings in Qdrant
- Search with decay algorithm
- Database relationships
- Error handling

.PARAMETER Token
API token for authentication

.PARAMETER FoldUrl
Server URL (default: http://localhost:8765)

.PARAMETER SampleFilesPath
Path to sample code files

.PARAMETER Verbose
Show detailed output
#>

param(
    [string]$Token = $env:FOLD_TOKEN,
    [string]$FoldUrl = "http://localhost:8765",
    [string]$SampleFilesPath = "d:\hh\git\g1\fold\test\sample-files",
    [string]$DbPath = "d:\hh\git\g1\fold\srv\data\fold.db",
    [switch]$Verbose
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
Write-Host "  FOLD V2 END-TO-END SYSTEM TEST" -ForegroundColor Cyan
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
Write-Host "`n2. PROJECT MANAGEMENT" -ForegroundColor White
$projectId = $null
try {
    $projectBody = @{
        name = "E2E Test Project"
        slug = "e2e-test-$(Get-Date -Format 'HHmmss')"
        description = "End-to-end system test"
        provider = "local"
        root_path = $SampleFilesPath
    } | ConvertTo-Json

    $project = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $projectBody -TimeoutSec 10
    $projectId = $project.id
    Write-Test "Create project" ($projectId -ne $null) "Project ID: $projectId"
} catch {
    Write-Test "Create project" $false "Error: $_"
    exit 1
}

# Test 3: Get Project
try {
    $retrievedProject = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId" -Headers $headers -TimeoutSec 5
    Write-Test "Retrieve project" ($retrievedProject.id -eq $projectId) "Name: $($retrievedProject.name)"
} catch {
    Write-Test "Retrieve project" $false "Error: $_"
}

# Test 4: List Projects
try {
    $projects = Invoke-RestMethod -Uri "$FoldUrl/projects" -Headers $headers -TimeoutSec 5
    $projectCount = $projects.projects.Count
    Write-Test "List projects" ($projectCount -gt 0) "Total projects: $projectCount"
} catch {
    Write-Test "List projects" $false "Error: $_"
}

# Test 5: Add Memories
Write-Host "`n3. MEMORY CREATION & STORAGE" -ForegroundColor White
$memoryIds = @()
$addedMemories = 0

if (Test-Path $SampleFilesPath) {
    Get-ChildItem $SampleFilesPath -File | Where-Object { $_.Extension -in ".rs", ".ts", ".md", ".py", ".txt" } | ForEach-Object {
        try {
            $content = [System.IO.File]::ReadAllText($_.FullName)
            if ($content.Length -gt 0 -and $content.Length -lt 100000) {
                $memBody = @{
                    title = $_.Name
                    content = $content
                    file_path = $_.Name
                    author = "e2e-test"
                } | ConvertTo-Json -Depth 10

                $mem = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/memories" -Method POST -Headers $headers -Body $memBody -TimeoutSec 30
                $memoryIds += $mem.id
                $addedMemories++
            }
        } catch {
            if ($Verbose) {
                Write-Host "Warning: Failed to add $($_.Name): $_" -ForegroundColor Yellow
            }
        }
    }
}

Write-Test "Add memories" ($addedMemories -gt 0) "Added $addedMemories files"

# Test 6: Verify Memories in Database
Write-Host "`n4. DATABASE VERIFICATION" -ForegroundColor White
Start-Sleep -Seconds 2

$dbMemCount = Query-Db "SELECT COUNT(*) FROM memories WHERE project_id = '$projectId';"
Write-Test "Memories in database" ($dbMemCount -eq $addedMemories) "Database count: $dbMemCount, Expected: $addedMemories"

# Test 7: Check Qdrant Vectors
Write-Host "`n5. VECTOR STORAGE (QDRANT)" -ForegroundColor White
try {
    $qdrantCollection = Invoke-RestMethod -Uri "http://localhost:6333/collections/fold_$($project.slug)" -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($qdrantCollection) {
        $vectorCount = $qdrantCollection.result.points_count
        $indexedVectors = $qdrantCollection.result.indexed_vectors_count
        Write-Test "Vectors stored in Qdrant" ($vectorCount -gt 0) "Points: $vectorCount, Indexed: $indexedVectors"
    } else {
        Write-Test "Vectors stored in Qdrant" $false "Collection not found in Qdrant"
    }
} catch {
    Write-Test "Vectors stored in Qdrant" $false "Qdrant connection failed"
}

# Test 8: Memory Verification
Write-Host "`n6. MEMORY VERIFICATION" -ForegroundColor White
$memCount = Query-Db "SELECT COUNT(*) FROM memories WHERE project_id = '$projectId';"
Write-Test "Memories stored" ($memCount -gt 0) "Total memories: $memCount"

# Test 9: Search Functionality
Write-Host "`n7. SEARCH & RETRIEVAL" -ForegroundColor White
try {
    $searchBody = @{ query = "function"; include_chunks = $true } | ConvertTo-Json
    $searchResults = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody -TimeoutSec 30
    $resultCount = $searchResults.results.Count
    Write-Test "Search returns results" ($resultCount -gt 0) "Results found: $resultCount"

    if ($resultCount -gt 0) {
        $firstResult = $searchResults.results[0]
        Write-Test "Search result has score" ($firstResult.score -ne $null) "Score: $($firstResult.score | ConvertTo-Json -Compress)"
        Write-Test "Search result has strength" ($firstResult.strength -ne $null) "Strength: $($firstResult.strength | ConvertTo-Json -Compress)"
        Write-Test "Search result has combined score" ($firstResult.combined_score -ne $null) "Combined: $($firstResult.combined_score | ConvertTo-Json -Compress)"
    }
} catch {
    Write-Test "Search returns results" $false "Error: $_"
}

# Test 10: Decay Algorithm
Write-Host "`n8. DECAY-WEIGHTED SEARCH" -ForegroundColor White

# Pure semantic (weight = 0)
try {
    $configBody = @{ strength_weight = 0.0 } | ConvertTo-Json
    Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $configBody -TimeoutSec 10 | Out-Null

    $searchBody = @{ query = "function"; include_chunks = $true } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody -TimeoutSec 30

    if ($result.results.Count -gt 0) {
        $r = $result.results[0]
        $scoreMatch = [math]::Abs($r.combined_score - $r.score) -lt 0.01
        Write-Test "Pure semantic (w=0)" $scoreMatch "Combined ≈ Semantic: $scoreMatch"
    } else {
        Write-Test "Pure semantic (w=0)" $false "No search results"
    }
} catch {
    Write-Test "Pure semantic (w=0)" $false "Error: $_"
}

# Balanced (weight = 0.3)
try {
    $configBody = @{ strength_weight = 0.3 } | ConvertTo-Json
    Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $configBody -TimeoutSec 10 | Out-Null

    $searchBody = @{ query = "function"; include_chunks = $true } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody -TimeoutSec 30

    Write-Test "Balanced decay (w=0.3)" ($result.results.Count -gt 0) "Results: $($result.results.Count)"
} catch {
    Write-Test "Balanced decay (w=0.3)" $false "Error: $_"
}

# Test 11: Configuration Management
Write-Host "`n9. CONFIGURATION MANAGEMENT" -ForegroundColor White
try {
    $config = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Headers $headers -TimeoutSec 5
    Write-Test "Read decay config" ($config.strength_weight -ne $null) "Weight: $($config.strength_weight), Half-life: $($config.decay_half_life_days)"

    $configBody = @{ decay_half_life_days = 14.0 } | ConvertTo-Json
    Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $configBody -TimeoutSec 10 | Out-Null

    $updatedConfig = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Headers $headers -TimeoutSec 5
    Write-Test "Update decay config" ($updatedConfig.decay_half_life_days -eq 14.0) "Updated to: $($updatedConfig.decay_half_life_days)"
} catch {
    Write-Test "Configuration management" $false "Error: $_"
}

# Test 12: Error Handling
Write-Host "`n10. ERROR HANDLING" -ForegroundColor White

try {
    $badConfig = @{ strength_weight = 1.5 } | ConvertTo-Json
    Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $badConfig -TimeoutSec 5 -ErrorAction Stop
    Write-Test "Reject invalid strength_weight" $false "Should have rejected value > 1.0"
} catch {
    Write-Test "Reject invalid strength_weight" ($_.Exception.Response.StatusCode -ge 400) "Correctly rejected"
}

try {
    $emptyMem = @{ title = "Empty"; content = "" } | ConvertTo-Json
    Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/memories" -Method POST -Headers $headers -Body $emptyMem -TimeoutSec 5 -ErrorAction Stop
    Write-Test "Reject empty memory content" $false "Should have rejected empty content"
} catch {
    Write-Test "Reject empty memory content" ($_.Exception.Response.StatusCode -ge 400) "Correctly rejected"
}

# Test 13: Cleanup
Write-Host "`n11. CLEANUP" -ForegroundColor White
try {
    Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId" -Method DELETE -Headers $headers -TimeoutSec 10 | Out-Null
    Write-Test "Delete project" $true "Project deleted"
} catch {
    Write-Test "Delete project" $false "Error: $_"
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
