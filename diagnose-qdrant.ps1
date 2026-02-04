#!/usr/bin/env powershell

<#
.SYNOPSIS
Diagnose Qdrant indexing and search issues

.DESCRIPTION
Tests Qdrant directly to identify why search isn't working
#>

param(
    [string]$Token = "fold_7tL9ZOLlVpC1EFhCxWsAfgjIlsyACfABGOyNCabt",
    [string]$FoldUrl = "http://localhost:8765",
    [string]$QdrantUrl = "http://localhost:6333",
    [string]$ProjectId = $null,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  QDRANT DIAGNOSTICS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: List Qdrant collections
Write-Host "1. QDRANT COLLECTIONS" -ForegroundColor White
try {
    $collections = Invoke-RestMethod -Uri "$QdrantUrl/collections" -TimeoutSec 10
    $collectionCount = $collections.result.collections.Count
    Write-Host "✅ Found $collectionCount collections`n" -ForegroundColor Green

    if ($collectionCount -gt 0) {
        $collections.result.collections | ForEach-Object {
            Write-Host "   Collection: $($_.name)" -ForegroundColor Gray
            Write-Host "      Vectors count: $($_.points_count)" -ForegroundColor Gray
            Write-Host "      Status: $($_.status)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "❌ Failed to list collections: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Get the latest project if not specified
if (-not $ProjectId) {
    Write-Host "`n2. FETCHING LATEST PROJECT" -ForegroundColor White
    try {
        $projects = Invoke-RestMethod -Uri "$FoldUrl/projects" -Headers $headers -TimeoutSec 10
        if ($projects.projects.Count -gt 0) {
            $ProjectId = $projects.projects[0].id
            $ProjectSlug = $projects.projects[0].slug
            Write-Host "✅ Using project: $ProjectSlug ($ProjectId)`n" -ForegroundColor Green
        } else {
            Write-Host "❌ No projects found" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "❌ Failed to fetch projects: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n2. USING PROVIDED PROJECT" -ForegroundColor White
    try {
        $project = Invoke-RestMethod -Uri "$FoldUrl/projects/$ProjectId" -Headers $headers -TimeoutSec 10
        $ProjectSlug = $project.slug
        Write-Host "✅ Project: $($project.slug) ($ProjectId)`n" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to fetch project: $_" -ForegroundColor Red
        exit 1
    }
}

# Step 3: Check the project's collection in Qdrant
$collectionName = "fold_$ProjectSlug"
Write-Host "3. CHECKING PROJECT COLLECTION: $collectionName" -ForegroundColor White
try {
    $collection = Invoke-RestMethod -Uri "$QdrantUrl/collections/$collectionName" -TimeoutSec 10
    $pointsCount = $collection.result.points_count
    $indexedCount = $collection.result.indexed_vectors_count
    Write-Host "✅ Collection found" -ForegroundColor Green
    Write-Host "   Total points: $pointsCount" -ForegroundColor Gray
    Write-Host "   Indexed vectors: $indexedCount`n" -ForegroundColor Gray

    # Check if vectors are indexed
    if ($indexedCount -eq 0 -and $pointsCount -gt 0) {
        Write-Host "⚠️  WARNING: Points exist but are not indexed!" -ForegroundColor Yellow
        Write-Host "   This could be a Qdrant indexing issue`n" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Failed to get collection: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Get a sample point from Qdrant to check its structure
Write-Host "4. CHECKING VECTOR STRUCTURE" -ForegroundColor White
try {
    $scrollResponse = Invoke-RestMethod -Uri "$QdrantUrl/collections/$collectionName/points" `
        -Method POST `
        -Body '{"limit": 1, "with_payload": true, "with_vectors": true}' `
        -TimeoutSec 10

    if ($scrollResponse.result.points.Count -gt 0) {
        $samplePoint = $scrollResponse.result.points[0]
        Write-Host "✅ Sample point retrieved" -ForegroundColor Green
        Write-Host "   Point ID: $($samplePoint.id)" -ForegroundColor Gray
        Write-Host "   Vector dimension: $($samplePoint.vector.Length)" -ForegroundColor Gray
        Write-Host "   Payload keys: $($samplePoint.payload.PSObject.Properties.Name -join ', ')" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host "❌ No points found in collection" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Failed to get sample point: $_" -ForegroundColor Red
}

# Step 5: Test a direct Qdrant search
Write-Host "5. TESTING DIRECT QDRANT SEARCH" -ForegroundColor White
try {
    # First, get a query vector by generating an embedding
    Write-Host "   Generating embedding for 'function'..." -ForegroundColor Gray
    $embed = @{ text = "function" } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$FoldUrl/projects/$ProjectId/embed" `
        -Method POST `
        -Headers $headers `
        -Body $embed `
        -TimeoutSec 10 -ErrorAction SilentlyContinue

    if ($response -and $response.embedding) {
        $queryVector = $response.embedding
        Write-Host "   ✅ Embedding generated (dimension: $($queryVector.Length))" -ForegroundColor Green

        # Now do a direct Qdrant search with this vector
        $searchPayload = @{
            vector = $queryVector
            limit = 5
            with_payload = $true
            score_threshold = 0.0
        } | ConvertTo-Json -Depth 10

        Write-Host "   Performing Qdrant search..." -ForegroundColor Gray
        $searchResults = Invoke-RestMethod -Uri "$QdrantUrl/collections/$collectionName/points/search" `
            -Method POST `
            -Body $searchPayload `
            -TimeoutSec 10

        $resultCount = $searchResults.result.Count
        Write-Host "   ✅ Search completed: $resultCount results found`n" -ForegroundColor Green

        if ($resultCount -gt 0) {
            Write-Host "   Top 3 results:" -ForegroundColor Gray
            $searchResults.result | Select-Object -First 3 | ForEach-Object {
                Write-Host "      ID: $($_.id), Score: $($_.score | ConvertTo-Json -Compress)" -ForegroundColor Gray
            }
        } else {
            Write-Host "   ⚠️  No results found in direct Qdrant search" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Failed to generate embedding" -ForegroundColor Red
    }
} catch {
    Write-Host "⚠️  Direct search test failed: $_" -ForegroundColor Yellow
}

# Step 6: Test the API search endpoint
Write-Host "`n6. TESTING API SEARCH ENDPOINT" -ForegroundColor White
try {
    $searchBody = @{ query = "function"; include_chunks = $true } | ConvertTo-Json
    $searchResults = Invoke-RestMethod -Uri "$FoldUrl/projects/$ProjectId/search" `
        -Method POST `
        -Headers $headers `
        -Body $searchBody `
        -TimeoutSec 30

    $resultCount = $searchResults.results.Count
    Write-Host "✅ API search completed: $resultCount results`n" -ForegroundColor $(if ($resultCount -gt 0) { "Green" } else { "Yellow" })

    if ($resultCount -gt 0) {
        Write-Host "   Top result:" -ForegroundColor Gray
        $first = $searchResults.results[0]
        Write-Host "      Title: $($first.title)" -ForegroundColor Gray
        Write-Host "      Score: $($first.score | ConvertTo-Json -Compress)" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ API search failed: $_" -ForegroundColor Red
}

# Step 7: Check if there's a filter issue
Write-Host "`n7. CHECKING COLLECTION CONFIGURATION" -ForegroundColor White
try {
    $config = Invoke-RestMethod -Uri "$QdrantUrl/collections/$collectionName" -TimeoutSec 10
    $config.result.config | ConvertTo-Json -Depth 3 | Write-Host
} catch {
    Write-Host "⚠️  Could not fetch collection config: $_" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  DIAGNOSIS COMPLETE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
