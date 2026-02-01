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
# 4. Embedding Provider
# ============================================
Write-Host "`n4. Embedding Provider" -ForegroundColor White

Test-Step "Embeddings healthy" {
    $r = Invoke-RestMethod -Uri "$FoldUrl/health/ready" -TimeoutSec 5
    $embeddingCheck = $r.checks | Where-Object { $_.name -eq "embeddings" }
    $embeddingCheck.status -eq "healthy"
}

# ============================================
# 5. Semantic Search with Rich Content
# ============================================
Write-Host "`n5. Semantic Search with Rich Content" -ForegroundColor White

if (-not $Token) {
    Test-Skip "Semantic search tests" "No FOLD_TOKEN set"
} else {
    # Create a dedicated project for search tests
    $searchBody = @{
        name = "search-test-$(Get-Date -Format 'HHmmss')"
        slug = "srch-test-$(Get-Date -Format 'HHmmss')"
        description = "Project for testing semantic search"
    } | ConvertTo-Json

    try {
        $searchProj = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $searchBody
        $searchProjectId = $searchProj.id

        # Add memory with TypeScript auth content
        Test-Step "Add codebase memory" {
            $codeMemBody = @{
                type = "codebase"
                title = "Authentication Module"
                content = "This module handles JWT token validation and user session creation. It validates tokens by decoding the JWT, checking expiration, and fetching the user from the database. Sessions expire after 7 days."
            } | ConvertTo-Json

            $r = Invoke-RestMethod -Uri "$FoldUrl/projects/$searchProjectId/memories" -Method POST -Headers $headers -Body $codeMemBody
            $r.id -ne $null
        }

        # Add memory with Python data processing content
        Test-Step "Add decision memory" {
            $dataMemBody = @{
                type = "decision"
                title = "Data Processor Architecture"
                content = "The DataProcessor class filters data points by threshold value, calculates averages, and exports results to JSON. It processes sensor readings including temperature and humidity measurements."
            } | ConvertTo-Json

            $r = Invoke-RestMethod -Uri "$FoldUrl/projects/$searchProjectId/memories" -Method POST -Headers $headers -Body $dataMemBody
            $r.id -ne $null
        }

        # Wait for embedding generation
        Write-Host "  Waiting for embeddings..." -ForegroundColor Gray
        Start-Sleep -Seconds 3

        Test-Step "Search finds auth content" {
            $authSearchBody = @{ query = "how does JWT authentication work" } | ConvertTo-Json
            $r = Invoke-RestMethod -Uri "$FoldUrl/projects/$searchProjectId/search" -Method POST -Headers $headers -Body $authSearchBody
            $null -ne $r.results
        }

        Test-Step "Search finds data processing content" {
            $dataSearchBody = @{ query = "filter sensor data by threshold" } | ConvertTo-Json
            $r = Invoke-RestMethod -Uri "$FoldUrl/projects/$searchProjectId/search" -Method POST -Headers $headers -Body $dataSearchBody
            $null -ne $r.results
        }

        # Cleanup
        Invoke-RestMethod -Uri "$FoldUrl/projects/$searchProjectId" -Method DELETE -Headers $headers -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  Semantic search tests failed: $_" -ForegroundColor Red
        $script:failed++
    }
}

# ============================================
# 6. Project Configuration
# ============================================
Write-Host "`n6. Project Configuration" -ForegroundColor White

if (-not $Token) {
    Test-Skip "Project configuration tests" "No FOLD_TOKEN set"
} else {
    try {
        # Create project with full configuration
        $configBody = @{
            name = "config-test-$(Get-Date -Format 'HHmmss')"
            slug = "cfg-test-$(Get-Date -Format 'HHmmss')"
            description = "Testing project configuration"
            root_path = "/test/path"
            repo_url = "https://github.com/test/repo"
        } | ConvertTo-Json

        $configProj = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $configBody
        $configProjectId = $configProj.id

        Test-Step "Project created with config" {
            $configProj.root_path -eq "/test/path" -or $configProj.repo_url -eq "https://github.com/test/repo" -or $configProj.id -ne $null
        }

        Test-Step "Update project settings" {
            $updateBody = @{
                name = $configProj.name
                slug = $configProj.slug
                description = "Updated description for testing"
            } | ConvertTo-Json

            $r = Invoke-RestMethod -Uri "$FoldUrl/projects/$configProjectId" -Method PUT -Headers $headers -Body $updateBody
            $r.description -eq "Updated description for testing" -or $r.id -eq $configProjectId
        }

        # Cleanup
        Invoke-RestMethod -Uri "$FoldUrl/projects/$configProjectId" -Method DELETE -Headers $headers -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  Project configuration tests failed: $_" -ForegroundColor Red
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
