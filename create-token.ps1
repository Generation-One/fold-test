# Create a test API token for Fold
param(
    [string]$UserId = "user-test-001",  # Test user that exists in database
    [string]$DbPath = "d:\hh\git\g1\fold\srv\data\fold.db"
)

# Generate token in format: fold_{8-char-prefix}_{32-char-secret}
# Using alphanumeric characters from base62 encoding

function Generate-RandomAlphanumeric {
    param([int]$Length)
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    $random = New-Object System.Random
    $result = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $result += $chars[$random.Next($chars.Length)]
    }
    return $result
}

$prefix = Generate-RandomAlphanumeric -Length 8
$secret = Generate-RandomAlphanumeric -Length 32
$token = "fold_" + $prefix + "_" + $secret

# Hash the FULL token (SHA256)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($token))
$hash = [BitConverter]::ToString($hashBytes) -replace '-',''
$hash = $hash.ToLower()

# Generate UUID for token ID
$tokenId = [guid]::NewGuid().ToString()

# Insert into database
# Note: project_ids in schema but empty for new security model
# Project access is now controlled via user/group membership, not token scope
$sql = @"
INSERT INTO api_tokens (id, user_id, name, token_hash, token_prefix, project_ids, created_at)
VALUES ('$tokenId', '$UserId', 'Test Token', '$hash', '$prefix', '[]', datetime('now'));
"@

try {
    sqlite3 $DbPath $sql
    Write-Host "Token created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "FOLD_TOKEN=$token" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Set this in your environment:" -ForegroundColor Yellow
    Write-Host "`$env:FOLD_TOKEN = `"$token`""
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
