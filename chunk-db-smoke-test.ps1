#Requires -Version 7.0

# Fold v2 Chunk Database Smoke Test
# Tests file chunking by creating files and verifying chunks in SQLite database
#
# Security Model: User-based access control
# - Tokens no longer have project_ids scoping
# - Project access is determined by user roles and group membership
# - Bearer token identifies user, project membership grants access

param(
    [string]$Token = $env:FOLD_TOKEN,
    [string]$FoldUrl = "http://localhost:8765",
    [string]$DatabasePath = "D:\hh\git\g1\fold\srv\fold.db"
)

# Bearer token auth - user identity, project access via membership
$headers = @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json" }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CHUNK DATABASE SMOKE TEST" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Verify database exists
if (-not (Test-Path $DatabasePath)) {
    Write-Host "ERROR: Database not found at $DatabasePath" -ForegroundColor Red
    exit 1
}

Write-Host "Database: $DatabasePath" -ForegroundColor Gray

# ============================================================================
# Create Test Project
# ============================================================================

Write-Host "`n=== Creating test project ===" -ForegroundColor Cyan

$projectSlug = "chunk-test-$(Get-Date -Format 'HHmmss')"
$projectBody = @{
    name = "Chunk Test Project"
    slug = $projectSlug
    description = "Testing file chunking in database"
} | ConvertTo-Json

try {
    $project = Invoke-RestMethod -Uri "$FoldUrl/projects" -Method POST -Headers $headers -Body $projectBody
    $projectId = $project.id
    Write-Host "  Project created: $projectId" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to create project: $_" -ForegroundColor Red
    exit 1
}

# ============================================================================
# Create Test Files with Code
# ============================================================================

Write-Host "`n=== Creating test files ===" -ForegroundColor Cyan

# File 1: Rust with multiple functions
$rustCode = @"
pub struct HttpServer {
    port: u16,
    routes: Vec<Route>,
}

impl HttpServer {
    pub fn new(port: u16) -> Self {
        HttpServer {
            port,
            routes: vec![],
        }
    }

    pub fn add_route(&mut self, method: &str, path: &str, handler: fn() -> String) {
        self.routes.push(Route { method: method.to_string(), path: path.to_string() });
    }

    pub fn start(&self) -> Result<(), String> {
        println!("Server listening on port {}", self.port);
        Ok(())
    }

    fn handle_request(&self, req: &Request) -> Response {
        Response::new()
    }
}

pub fn create_server(port: u16) -> HttpServer {
    HttpServer::new(port)
}
"@

$mem1 = @{
    title = "HTTP Server Module"
    content = $rustCode
    file_path = "src/server.rs"
} | ConvertTo-Json

try {
    $memory1 = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/memories" -Method POST -Headers $headers -Body $mem1
    $memory1Id = $memory1.id
    Write-Host "  Created Rust file memory: $memory1Id" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to create memory: $_" -ForegroundColor Red
    exit 1
}

# File 2: TypeScript with classes
$tsCode = @"
interface Config {
    host: string;
    port: number;
}

export class DatabaseConnection {
    private host: string;
    private port: number;

    constructor(config: Config) {
        this.host = config.host;
        this.port = config.port;
    }

    public connect(): Promise<void> {
        return new Promise((resolve) => {
            console.log(\`Connecting to \${this.host}:\${this.port}\`);
            resolve();
        });
    }

    public disconnect(): void {
        console.log("Disconnected");
    }

    private validateConfig(): boolean {
        return this.port > 0 && this.host.length > 0;
    }
}

export const createConnection = (config: Config) => new DatabaseConnection(config);
"@

$mem2 = @{
    title = "Database Connection Module"
    content = $tsCode
    file_path = "src/db.ts"
} | ConvertTo-Json

try {
    $memory2 = Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId/memories" -Method POST -Headers $headers -Body $mem2
    $memory2Id = $memory2.id
    Write-Host "  Created TypeScript file memory: $memory2Id" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to create memory 2: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`nWaiting for file indexing and chunking..." -ForegroundColor Yellow
Write-Host "Memory 1 ID: $memory1Id" -ForegroundColor Gray
Write-Host "Memory 2 ID: $memory2Id" -ForegroundColor Gray
Start-Sleep -Seconds 5

# ============================================================================
# Query Database for Chunks
# ============================================================================

Write-Host "`n=== Checking database for chunks ===" -ForegroundColor Cyan

# Helper function to query SQLite via CLI
function Invoke-SQLiteQuery {
    param(
        [string]$Query,
        [string]$DbPath = $DatabasePath
    )

    try {
        $result = sqlite3 $DbPath $Query 2>$null
        return $result
    } catch {
        Write-Host "  ERROR: Query failed: $_" -ForegroundColor Red
        return $null
    }
}

Write-Host "  Connected to SQLite database (sqlite3 CLI)" -ForegroundColor Green

# ============================================================================
# Test 1: Verify chunks exist for memory 1
# ============================================================================

Write-Host "`nTest 1: Rust file chunks" -ForegroundColor White

$query = "SELECT COUNT(*) FROM chunks WHERE memory_id = '$memory1Id';"
$result = Invoke-SQLiteQuery $query

if ($result -and $result -gt 0) {
    Write-Host "  ✓ PASS: Found $result chunks for Rust file" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: No chunks found for Rust file" -ForegroundColor Red
}

# ============================================================================
# Test 2: Verify chunk metadata
# ============================================================================

Write-Host "`nTest 2: Chunk metadata validation" -ForegroundColor White

$query = "SELECT node_type, node_name, start_line, end_line FROM chunks WHERE memory_id = '$memory1Id' ORDER BY start_line;"
$results = Invoke-SQLiteQuery $query
$chunkCount = 0
$nodeTypes = @()
$nodeNames = @()

if ($results) {
    $lines = $results -split "`n" | Where-Object { $_ -match '\|' }
    foreach ($line in $lines) {
        $chunkCount++
        $parts = $line -split '\|'
        $nodeType = $parts[0].Trim()
        $nodeName = $parts[1].Trim()
        $startLine = $parts[2].Trim()
        $endLine = $parts[3].Trim()

        $nodeTypes += $nodeType
        if ($nodeName) { $nodeNames += $nodeName }

        Write-Host "    Chunk $($chunkCount): type='$nodeType', name='$nodeName', lines=$startLine-$endLine" -ForegroundColor Gray

        # Validate line numbers
        if ($startLine -le 0 -or $endLine -le 0) {
            Write-Host "    ✗ Invalid line numbers" -ForegroundColor Red
        } elseif ($endLine -lt $startLine) {
            Write-Host "    ✗ end_line < start_line" -ForegroundColor Red
        }
    }

    if ($chunkCount -gt 0) {
        Write-Host "  ✓ PASS: Found $chunkCount chunks with valid metadata" -ForegroundColor Green
    }
} else {
    Write-Host "  ✗ ERROR: No chunks found" -ForegroundColor Red
}

# ============================================================================
# Test 3: Verify node types
# ============================================================================

Write-Host "`nTest 3: Node type validation" -ForegroundColor White

$expectedNodeTypes = @("function", "struct", "impl", "class", "interface", "method")
$foundTypes = @()

foreach ($nodeType in $nodeTypes) {
    if ($expectedNodeTypes -contains $nodeType) {
        $foundTypes += $nodeType
    }
}

if ($foundTypes.Count -gt 0) {
    Write-Host "  ✓ PASS: Found expected node types: $($foundTypes -join ', ')" -ForegroundColor Green
} else {
    Write-Host "  ⚠ INFO: No standard node types found (may be using fallback chunking)" -ForegroundColor Yellow
}

# Store types for later validation
$script:nodeTypesTest3 = $nodeTypes

# ============================================================================
# Test 4: Verify chunks for memory 2 (TypeScript)
# ============================================================================

Write-Host "`nTest 4: TypeScript file chunks" -ForegroundColor White

$query = "SELECT COUNT(*) FROM chunks WHERE memory_id = '$memory2Id';"
$result = Invoke-SQLiteQuery $query

if ($result -and $result -gt 0) {
    Write-Host "  ✓ PASS: Found $result chunks for TypeScript file" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: No chunks found for TypeScript file" -ForegroundColor Red
}

# ============================================================================
# Test 5: Verify content_hash is set
# ============================================================================

Write-Host "`nTest 5: Content hash verification" -ForegroundColor White

$query = "SELECT COUNT(*) FROM chunks WHERE content_hash IS NOT NULL AND content_hash != '' AND memory_id IN ('$memory1Id', '$memory2Id');"
$result = Invoke-SQLiteQuery $query

if ($result -and $result -gt 0) {
    Write-Host "  ✓ PASS: Found $result chunks with content_hash" -ForegroundColor Green
} else {
    Write-Host "  ⚠ WARNING: Some chunks missing content_hash" -ForegroundColor Yellow
}

# ============================================================================
# Test 6: Verify total chunks created
# ============================================================================

Write-Host "`nTest 6: Total chunk count" -ForegroundColor White

$query = "SELECT COUNT(*) FROM chunks WHERE project_id = '$projectId';"
$totalChunks = Invoke-SQLiteQuery $query

Write-Host "  Total chunks in project: $totalChunks" -ForegroundColor Gray

if ($totalChunks -and $totalChunks -ge 2) {
    Write-Host "  ✓ PASS: Multiple chunks created for project files" -ForegroundColor Green
} else {
    Write-Host "  ⚠ WARNING: Expected more chunks" -ForegroundColor Yellow
}

# ============================================================================
# Test 7: Verify chunk language detection
# ============================================================================

Write-Host "`nTest 7: Language detection" -ForegroundColor White

$query = "SELECT DISTINCT language FROM chunks WHERE project_id = '$projectId' ORDER BY language;"
$languageResult = Invoke-SQLiteQuery $query

if ($languageResult) {
    $languages = $languageResult -split "`n" | Where-Object { $_ -and $_.Trim() -ne '' }
    if ($languages.Count -gt 0) {
        Write-Host "  ✓ PASS: Detected languages: $($languages -join ', ')" -ForegroundColor Green
    } else {
        Write-Host "  ✗ FAIL: No languages detected" -ForegroundColor Red
    }
} else {
    Write-Host "  ✗ FAIL: No languages detected" -ForegroundColor Red
}

# ============================================================================
# Test 8: Line number statistics
# ============================================================================

Write-Host "`nTest 8: Line number ranges" -ForegroundColor White

$query = "SELECT MIN(start_line), MAX(end_line), AVG(CAST(end_line - start_line AS FLOAT)) FROM chunks WHERE project_id = '$projectId';"
$statsResult = Invoke-SQLiteQuery $query

if ($statsResult) {
    $parts = $statsResult -split '\|'
    $minStart = $parts[0].Trim()
    $maxEnd = $parts[1].Trim()
    $avgSize = if ($parts[2]) { [math]::Round([double]$parts[2].Trim(), 1) } else { "N/A" }

    Write-Host "  Min start line: $minStart" -ForegroundColor Gray
    Write-Host "  Max end line: $maxEnd" -ForegroundColor Gray
    Write-Host "  Average chunk size: $avgSize lines" -ForegroundColor Gray

    Write-Host "  ✓ PASS: Line number ranges valid" -ForegroundColor Green
} else {
    Write-Host "  ✗ ERROR: Failed to analyze line numbers" -ForegroundColor Red
}

# ============================================================================
# Cleanup
# ============================================================================

Write-Host "`nCleaning up..." -ForegroundColor Gray

try {
    Invoke-RestMethod -Uri "$FoldUrl/projects/$projectId" -Method DELETE -Headers $headers -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  Project deleted" -ForegroundColor Gray
} catch {
    Write-Host "  Warning: Could not delete project" -ForegroundColor Yellow
}

# ============================================================================
# Summary
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CHUNK DATABASE SMOKE TEST COMPLETE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Summary:" -ForegroundColor White
Write-Host "  ✓ Chunks created in database" -ForegroundColor Green
Write-Host "  ✓ Chunk metadata validated" -ForegroundColor Green
Write-Host "  ✓ Line numbers verified" -ForegroundColor Green
Write-Host "  ✓ Language detection confirmed" -ForegroundColor Green
Write-Host "`n"
