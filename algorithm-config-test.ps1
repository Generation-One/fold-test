# Algorithm Configuration Test
# Tests the /projects/:id/config/algorithm endpoint

param(
    [string]$Token = $env:FOLD_TOKEN,
    [string]$FoldUrl = "http://localhost:8765"
)

$headers = @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json" }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ALGORITHM CONFIGURATION TEST" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Create test project
Write-Host "Creating test project..." -ForegroundColor White
$projectBody = @{
    name = "algo-config-test"
    slug = "algo-config-$(Get-Date -Format 'HHmmss')"
    description = "Testing algorithm configuration"
} | ConvertTo-Json

$project = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $projectBody
$projectId = $project.id
Write-Host "  Project: $($project.name) [$projectId]" -ForegroundColor Green

$script:passed = 0
$script:failed = 0

# Test 1: Get default algorithm config
Write-Host "`nTest 1: Get default algorithm config" -ForegroundColor White
try {
    $config = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method GET -Headers $headers
    Write-Host "  strength_weight: $($config.strength_weight)" -ForegroundColor Gray
    Write-Host "  decay_half_life_days: $($config.decay_half_life_days)" -ForegroundColor Gray
    if ($config.strength_weight -eq 0.3 -and $config.decay_half_life_days -eq 30) {
        Write-Host "  PASS: Default values are correct" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  FAIL: Expected strength_weight=0.3, decay_half_life_days=30" -ForegroundColor Red
        $script:failed++
    }
} catch {
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $script:failed++
}

# Test 2: Update strength_weight
Write-Host "`nTest 2: Update strength_weight to 0.5" -ForegroundColor White
try {
    $updateBody = @{ strength_weight = 0.5 } | ConvertTo-Json
    $config = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $updateBody
    if ($config.strength_weight -eq 0.5) {
        Write-Host "  PASS: strength_weight updated to 0.5" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  FAIL: strength_weight is $($config.strength_weight), expected 0.5" -ForegroundColor Red
        $script:failed++
    }
} catch {
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $script:failed++
}

# Test 3: Update decay_half_life_days
Write-Host "`nTest 3: Update decay_half_life_days to 7" -ForegroundColor White
try {
    $updateBody = @{ decay_half_life_days = 7.0 } | ConvertTo-Json
    $config = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $updateBody
    if ($config.decay_half_life_days -eq 7) {
        Write-Host "  PASS: decay_half_life_days updated to 7" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  FAIL: decay_half_life_days is $($config.decay_half_life_days), expected 7" -ForegroundColor Red
        $script:failed++
    }
} catch {
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $script:failed++
}

# Test 4: Update ignored_commit_authors
Write-Host "`nTest 4: Update ignored_commit_authors" -ForegroundColor White
try {
    $updateBody = @{ ignored_commit_authors = @("my-ci-bot", "deploy-bot") } | ConvertTo-Json
    $config = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $updateBody
    if ($config.ignored_commit_authors.Count -eq 2 -and $config.ignored_commit_authors[0] -eq "my-ci-bot") {
        Write-Host "  PASS: ignored_commit_authors updated" -ForegroundColor Green
        Write-Host "  Authors: $($config.ignored_commit_authors -join ', ')" -ForegroundColor Gray
        $script:passed++
    } else {
        Write-Host "  FAIL: ignored_commit_authors not updated correctly" -ForegroundColor Red
        $script:failed++
    }
} catch {
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $script:failed++
}

# Test 5: Verify all values persisted
Write-Host "`nTest 5: Verify all values persisted" -ForegroundColor White
try {
    $config = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method GET -Headers $headers
    $allCorrect = (
        $config.strength_weight -eq 0.5 -and
        $config.decay_half_life_days -eq 7 -and
        $config.ignored_commit_authors.Count -eq 2
    )
    if ($allCorrect) {
        Write-Host "  PASS: All values persisted correctly" -ForegroundColor Green
        Write-Host "  strength_weight: $($config.strength_weight)" -ForegroundColor Gray
        Write-Host "  decay_half_life_days: $($config.decay_half_life_days)" -ForegroundColor Gray
        Write-Host "  ignored_commit_authors: $($config.ignored_commit_authors -join ', ')" -ForegroundColor Gray
        $script:passed++
    } else {
        Write-Host "  FAIL: Values not persisted correctly" -ForegroundColor Red
        $script:failed++
    }
} catch {
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $script:failed++
}

# Test 6: Invalid strength_weight (should fail)
Write-Host "`nTest 6: Reject invalid strength_weight (1.5)" -ForegroundColor White
try {
    $updateBody = @{ strength_weight = 1.5 } | ConvertTo-Json
    $config = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/config/algorithm" -Method PUT -Headers $headers -Body $updateBody
    Write-Host "  FAIL: Should have rejected invalid value" -ForegroundColor Red
    $script:failed++
} catch {
    if ($_.Exception.Message -match "between 0.0 and 1.0" -or $_.Exception.Response.StatusCode -ge 400) {
        Write-Host "  PASS: Correctly rejected invalid strength_weight" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  FAIL: Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
    }
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
    Write-Host "`nAlgorithm configuration working correctly!" -ForegroundColor Green
    exit 0
}
