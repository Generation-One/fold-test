# Unified Search Decay Test
# Tests that the /projects/:id/search endpoint supports decay parameters

param(
    [string]$Token = $env:FOLD_TOKEN,
    [string]$FoldUrl = "http://localhost:8765"
)

$headers = @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json" }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  UNIFIED SEARCH DECAY TEST" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Create test project
Write-Host "Creating test project..." -ForegroundColor White
$projectBody = @{
    name = "unified-decay-test"
    slug = "unified-decay-$(Get-Date -Format 'HHmmss')"
    description = "Testing unified search decay parameters"
} | ConvertTo-Json

$project = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $projectBody
$projectId = $project.id
Write-Host "  Project: $($project.name) [$projectId]" -ForegroundColor Green

Write-Host "`n=== Adding memory ===" -ForegroundColor Cyan

$memBody = @{
    type = "general"
    title = "API Guide"
    content = "This guide explains REST API authentication using JWT tokens and OAuth flows."
} | ConvertTo-Json
$mem = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/memories" -Method POST -Headers $headers -Body $memBody
Write-Host "  Added: $($mem.title)" -ForegroundColor Gray

Write-Host "`nWaiting for embedding..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

Write-Host "`n=== Testing unified search with decay params ===" -ForegroundColor Cyan

$script:passed = 0
$script:failed = 0

# Test 1: Default parameters
Write-Host "`nTest 1: Default parameters (strength_weight=0.3, half_life=30)" -ForegroundColor White
$searchBody = @{
    query = "API authentication"
} | ConvertTo-Json
$result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody
if ($result.results.Count -gt 0) {
    $r = $result.results[0]
    Write-Host "  score=$([math]::Round($r.score, 3)), strength=$([math]::Round($r.strength, 3)), combined=$([math]::Round($r.combined_score, 3))" -ForegroundColor Gray
    if ($null -ne $r.strength -and $null -ne $r.combined_score) {
        Write-Host "  PASS: Response includes strength and combined_score fields" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  FAIL: Missing decay fields in response" -ForegroundColor Red
        $script:failed++
    }
} else {
    Write-Host "  FAIL: No results returned" -ForegroundColor Red
    $script:failed++
}

# Test 2: Pure semantic (strength_weight=0)
Write-Host "`nTest 2: Pure semantic (strength_weight=0)" -ForegroundColor White
$searchBody = @{
    query = "API authentication"
    strength_weight = 0.0
    decay_half_life_days = 30
} | ConvertTo-Json
$result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody
if ($result.results.Count -gt 0) {
    $r = $result.results[0]
    Write-Host "  score=$([math]::Round($r.score, 3)), strength=$([math]::Round($r.strength, 3)), combined=$([math]::Round($r.combined_score, 3))" -ForegroundColor Gray
    if ([math]::Abs($r.score - $r.combined_score) -lt 0.01) {
        Write-Host "  PASS: combined_score equals semantic score (no decay weighting)" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  FAIL: combined_score should equal score when strength_weight=0" -ForegroundColor Red
        $script:failed++
    }
} else {
    Write-Host "  FAIL: No results returned" -ForegroundColor Red
    $script:failed++
}

# Test 3: Pure strength (strength_weight=1.0)
Write-Host "`nTest 3: Pure strength (strength_weight=1.0)" -ForegroundColor White
$searchBody = @{
    query = "API authentication"
    strength_weight = 1.0
    decay_half_life_days = 30
} | ConvertTo-Json
$result = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/search" -Method POST -Headers $headers -Body $searchBody
if ($result.results.Count -gt 0) {
    $r = $result.results[0]
    Write-Host "  score=$([math]::Round($r.score, 3)), strength=$([math]::Round($r.strength, 3)), combined=$([math]::Round($r.combined_score, 3))" -ForegroundColor Gray
    if ([math]::Abs($r.combined_score - $r.strength) -lt 0.01) {
        Write-Host "  PASS: combined_score equals strength (pure strength mode)" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  FAIL: combined_score should equal strength when strength_weight=1" -ForegroundColor Red
        $script:failed++
    }
} else {
    Write-Host "  FAIL: No results returned" -ForegroundColor Red
    $script:failed++
}

# Cleanup
Write-Host "`nCleaning up test project..." -ForegroundColor Gray
Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId" -Method DELETE -Headers $headers -ErrorAction SilentlyContinue | Out-Null

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Passed:  $script:passed" -ForegroundColor Green
Write-Host "  Failed:  $script:failed" -ForegroundColor $(if ($script:failed -gt 0) { "Red" } else { "Green" })

if ($script:failed -gt 0) {
    exit 1
} else {
    Write-Host "`nUnified search decay parameters working correctly!" -ForegroundColor Green
    exit 0
}
