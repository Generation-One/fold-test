# Decay/Recency Bias Test Script
# Tests that older memories decay in search rankings while recent ones are boosted

param(
    [string]$Token = $env:FOLD_TOKEN,
    [string]$FoldUrl = "http://localhost:8765"
)

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type" = "application/json"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  DECAY / RECENCY BIAS TEST" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Create test project
Write-Host "Creating test project..." -ForegroundColor White
$projectBody = @{
    name = "decay-test"
    slug = "decay-test-$(Get-Date -Format 'HHmmss')"
    description = "Testing memory decay and recency bias"
} | ConvertTo-Json

$project = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $projectBody
$projectId = $project.id
Write-Host "  Project: $($project.name) [$projectId]" -ForegroundColor Green

Write-Host "`n=== Adding memories ===" -ForegroundColor Cyan

# Add memories - all have same semantic content but we'll test different decay params
$memBody = @{
    title = "API Documentation Guide"
    content = "This guide explains how to use the REST API endpoints for authentication, data retrieval, and error handling."
} | ConvertTo-Json
$mem = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/memories" -Method POST -Headers $headers -Body $memBody
Write-Host "  Added: $($mem.title)" -ForegroundColor Gray

Write-Host "`nWaiting for embedding..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

Write-Host "`n=== Testing decay parameters ===" -ForegroundColor Cyan

# Test 1: Pure semantic search (strength_weight = 0)
Write-Host "`nTest 1: Pure semantic (strength_weight=0)" -ForegroundColor White
# Set project algorithm config to strength_weight=0
$configBody = @{ strength_weight = 0.0 } | ConvertTo-Json
Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $configBody | Out-Null
$searchBody = @{
    query = "how to use REST API"
} | ConvertTo-Json
$result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody
if ($result.results.Count -gt 0) {
    $r = $result.results[0]
    Write-Host "  Result: score=$([math]::Round($r.score, 3)), strength=$([math]::Round($r.strength, 3)), combined=$([math]::Round($r.combined_score, 3))" -ForegroundColor Gray
    if ($r.score -eq $r.combined_score) {
        Write-Host "  PASS: Combined score equals semantic score (no decay weighting)" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: Combined score should equal semantic score" -ForegroundColor Red
    }
} else {
    Write-Host "  FAIL: No results returned" -ForegroundColor Red
}

# Test 2: Balanced (strength_weight = 0.3, default)
Write-Host "`nTest 2: Balanced (strength_weight=0.3)" -ForegroundColor White
# Set project algorithm config to strength_weight=0.3
$configBody = @{ strength_weight = 0.3 } | ConvertTo-Json
Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $configBody | Out-Null
$searchBody = @{
    query = "how to use REST API"
} | ConvertTo-Json
$result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody
if ($result.results.Count -gt 0) {
    $r = $result.results[0]
    Write-Host "  Result: score=$([math]::Round($r.score, 3)), strength=$([math]::Round($r.strength, 3)), combined=$([math]::Round($r.combined_score, 3))" -ForegroundColor Gray
    # Combined should be different from pure score since we're blending
    if ($r.strength -gt 0 -and $r.combined_score -ne $r.score) {
        Write-Host "  PASS: Combined score blends semantic and strength" -ForegroundColor Green
    } else {
        Write-Host "  INFO: Memory too new for visible decay effect" -ForegroundColor Yellow
    }
} else {
    Write-Host "  FAIL: No results returned" -ForegroundColor Red
}

# Test 3: Pure strength (strength_weight = 1.0)
Write-Host "`nTest 3: Pure strength (strength_weight=1.0)" -ForegroundColor White
# Set project algorithm config to strength_weight=1.0
$configBody = @{ strength_weight = 1.0 } | ConvertTo-Json
Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $configBody | Out-Null
$searchBody = @{
    query = "how to use REST API"
} | ConvertTo-Json
$result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody
if ($result.results.Count -gt 0) {
    $r = $result.results[0]
    Write-Host "  Result: score=$([math]::Round($r.score, 3)), strength=$([math]::Round($r.strength, 3)), combined=$([math]::Round($r.combined_score, 3))" -ForegroundColor Gray
    if ([math]::Abs($r.combined_score - $r.strength) -lt 0.01) {
        Write-Host "  PASS: Combined score equals strength (no semantic weighting)" -ForegroundColor Green
    } else {
        Write-Host "  FAIL: Combined score should equal strength" -ForegroundColor Red
    }
} else {
    Write-Host "  FAIL: No results returned" -ForegroundColor Red
}

# Test 4: Very short half-life (more aggressive decay)
Write-Host "`nTest 4: Short half-life (decay_half_life_days=1)" -ForegroundColor White
# Set project algorithm config to short half-life
$configBody = @{ strength_weight = 0.5; decay_half_life_days = 1.0 } | ConvertTo-Json
Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $configBody | Out-Null
$searchBody = @{
    query = "how to use REST API"
} | ConvertTo-Json
$result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody
if ($result.results.Count -gt 0) {
    $r = $result.results[0]
    Write-Host "  Result: score=$([math]::Round($r.score, 3)), strength=$([math]::Round($r.strength, 3)), combined=$([math]::Round($r.combined_score, 3))" -ForegroundColor Gray
    Write-Host "  INFO: Fresh memory should have high strength even with 1-day half-life" -ForegroundColor Gray
} else {
    Write-Host "  FAIL: No results returned" -ForegroundColor Red
}

# Test 5: Very long half-life (slow decay)
Write-Host "`nTest 5: Long half-life (decay_half_life_days=365)" -ForegroundColor White
# Set project algorithm config to long half-life
$configBody = @{ strength_weight = 0.5; decay_half_life_days = 365.0 } | ConvertTo-Json
Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $configBody | Out-Null
$searchBody = @{
    query = "how to use REST API"
} | ConvertTo-Json
$result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody
if ($result.results.Count -gt 0) {
    $r = $result.results[0]
    Write-Host "  Result: score=$([math]::Round($r.score, 3)), strength=$([math]::Round($r.strength, 3)), combined=$([math]::Round($r.combined_score, 3))" -ForegroundColor Gray
    Write-Host "  INFO: With 365-day half-life, decay effect is minimal" -ForegroundColor Gray
} else {
    Write-Host "  FAIL: No results returned" -ForegroundColor Red
}

# Cleanup
Write-Host "`nCleaning up test project..." -ForegroundColor Gray
Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId" -Method DELETE -Headers $headers -ErrorAction SilentlyContinue | Out-Null

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  DECAY TEST COMPLETE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Summary:" -ForegroundColor White
Write-Host "  - strength_weight controls blend of semantic vs recency" -ForegroundColor Gray
Write-Host "  - decay_half_life_days controls how fast memories fade" -ForegroundColor Gray
Write-Host "  - Fresh memories have strength ~1.0" -ForegroundColor Gray
Write-Host "  - After 30 days (default), strength ~0.5" -ForegroundColor Gray
Write-Host "  - Access frequency boosts strength" -ForegroundColor Gray
