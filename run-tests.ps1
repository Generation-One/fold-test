# Fold Test Runner
# Runs all tests and reports results

param(
    [string]$FoldUrl = "http://localhost:8765",
    [string]$Token = $env:FOLD_TOKEN
)

$ErrorActionPreference = "Continue"
$script:passed = 0
$script:failed = 0
$script:skipped = 0

function Test-Step {
    param([string]$Name, [scriptblock]$Test)

    Write-Host -NoNewline "  $Name... "
    try {
        $result = & $Test
        if ($result) {
            Write-Host "PASS" -ForegroundColor Green
            $script:passed++
        } else {
            Write-Host "FAIL" -ForegroundColor Red
            $script:failed++
        }
    } catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
        $script:failed++
    }
}

function Test-Skip {
    param([string]$Name, [string]$Reason)
    Write-Host "  $Name... SKIP ($Reason)" -ForegroundColor Yellow
    $script:skipped++
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  FOLD TEST SUITE" -ForegroundColor Cyan
Write-Host "  Server: $FoldUrl" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ============================================
# 1. Health & Connectivity
# ============================================
Write-Host "1. Health & Connectivity" -ForegroundColor White

Test-Step "Server health" {
    $r = Invoke-RestMethod -Uri "$FoldUrl/health" -TimeoutSec 5
    $r.status -eq "ok" -or $r.status -eq "healthy"
}

Test-Step "Qdrant connection" {
    $r = Invoke-RestMethod -Uri "$FoldUrl/health/ready" -TimeoutSec 5
    $qdrantCheck = $r.checks | Where-Object { $_.name -eq "qdrant" }
    $r.ready -eq $true -and $qdrantCheck.status -eq "healthy"
}

# ============================================
# 2. Project Management
# ============================================
Write-Host "`n2. Project Management" -ForegroundColor White

if (-not $Token) {
    Test-Skip "Create project" "No FOLD_TOKEN set"
    Test-Skip "List projects" "No FOLD_TOKEN set"
    Test-Skip "Delete project" "No FOLD_TOKEN set"
} else {
    $headers = @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json" }
    $testProjectId = $null

    Test-Step "Create project" {
        $body = @{
            name = "test-project-$(Get-Date -Format 'HHmmss')"
            slug = "test-proj-$(Get-Date -Format 'HHmmss')"
            description = "Automated test project"
        } | ConvertTo-Json

        $r = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $body
        $script:testProjectId = $r.id
        $r.id -ne $null
    }

    Test-Step "List projects" {
        $r = Invoke-RestMethod -Uri "$FoldUrl/projects" -Headers $headers
        $r.projects -ne $null -and $r.total -ge 0
    }

    if ($testProjectId) {
        Test-Step "Get project" {
            $r = Invoke-RestMethod -Uri "$FoldUrl/projects/$testProjectId" -Headers $headers
            $r.id -eq $testProjectId
        }

        Test-Step "Delete project" {
            Invoke-RestMethod -Uri "$FoldUrl/projects/$testProjectId" -Method DELETE -Headers $headers
            $true
        }
    }
}

# ============================================
# 3. Memory Operations
# ============================================
Write-Host "`n3. Memory Operations" -ForegroundColor White

if (-not $Token) {
    Test-Skip "Memory operations" "No FOLD_TOKEN set"
} else {
    # Create a test project for memory tests
    $body = @{
        name = "memory-test-$(Get-Date -Format 'HHmmss')"
        slug = "mem-test-$(Get-Date -Format 'HHmmss')"
    } | ConvertTo-Json

    try {
        $proj = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $body
        $memProjectId = $proj.id

        Test-Step "Add memory" {
            $memBody = @{
                type = "general"
                title = "Test Memory"
                content = "This is a test memory for automated testing."
            } | ConvertTo-Json

            $r = Invoke-RestMethod -Uri "$FoldUrl/projects/$memProjectId/memories" -Method POST -Headers $headers -Body $memBody
            $script:testMemoryId = $r.id
            $r.id -ne $null
        }

        Test-Step "List memories" {
            $r = Invoke-RestMethod -Uri "$FoldUrl/projects/$memProjectId/memories" -Headers $headers
            $r.memories -ne $null -and $r.total -ge 1
        }

        Test-Step "Search memories" {
            $searchBody = @{ query = "test memory automated" } | ConvertTo-Json
            $r = Invoke-RestMethod -Uri "$FoldUrl/projects/$memProjectId/search" -Method POST -Headers $headers -Body $searchBody
            # Just verify we get a valid response structure (results may be empty for new memories)
            $null -ne $r.results
        }

        # Cleanup
        Invoke-RestMethod -Uri "$FoldUrl/projects/$memProjectId" -Method DELETE -Headers $headers -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  Memory tests failed: $_" -ForegroundColor Red
        $script:failed++
    }
}

# ============================================
# Summary
# ============================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Passed:  $script:passed" -ForegroundColor Green
Write-Host "  Failed:  $script:failed" -ForegroundColor $(if ($script:failed -gt 0) { "Red" } else { "Green" })
Write-Host "  Skipped: $script:skipped" -ForegroundColor Yellow
Write-Host ""

if ($script:failed -gt 0) {
    exit 1
} else {
    exit 0
}
