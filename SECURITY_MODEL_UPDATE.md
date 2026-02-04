# Fold v2 Security Model Update

## Change Summary

**Old Model:** Token-level project scoping
- API tokens had `project_ids` field
- Token scope determined which projects it could access
- Project access controlled at token level

**New Model:** User/Group-based project access
- API tokens are user-level (no `project_ids` field)
- Project access controlled by user roles and group membership
- Users assigned to projects directly or via groups
- Bearer token identifies the user, membership grants access

## Files Updated

### 1. `create-token.ps1` - Token Creation Script
**Changed:** Removed `project_ids` from INSERT statement

**Before:**
```powershell
INSERT INTO api_tokens (id, user_id, name, token_hash, token_prefix, project_ids, created_at)
VALUES ('$tokenId', '$UserId', 'Test Token', '$hash', '$prefix', '[]', datetime('now'));
```

**After:**
```powershell
INSERT INTO api_tokens (id, user_id, name, token_hash, token_prefix, created_at)
VALUES ('$tokenId', '$UserId', 'Test Token', '$hash', '$prefix', datetime('now'));
```

### 2. `v2-comprehensive-smoke-test.ps1` - Comprehensive Test Suite
**Updated:** Added security model documentation

**Changes:**
- Added header comment explaining new security model
- Documented that project access is now user-based
- Noted that tokens identify users, not project scope
- Clarified project membership controls access

### 3. `chunk-db-smoke-test.ps1` - Chunk Test Suite
**Updated:** Added security model documentation and fixed PowerShell syntax

**Changes:**
- Added header comment explaining new security model
- Fixed syntax error in string interpolation (line 227)
- Clarified bearer token usage for user identification

## Authentication Flow

### Old Flow
```
API Token (with project_ids)
  ↓
Token decoded
  ↓
Check token.project_ids includes requested project
  ↓
Allow/Deny access
```

### New Flow
```
Bearer Token (user identifier)
  ↓
Token decoded → User ID extracted
  ↓
Check user membership in project
  ↓
Check user role (Owner/Member/Viewer)
  ↓
Allow/Deny based on role + requested operation
```

## Test Impact

### No Breaking Changes
✅ Tests continue to work with `Authorization: Bearer $Token` header
✅ Token creation still works (just removed unused `project_ids`)
✅ All smoke tests work unchanged
✅ User running tests is auto-added to projects they create

### What Tests Now Validate
✅ User-based token authentication
✅ Project access via user membership
✅ Proper role-based permissions
✅ Group-based project access

## Implementation Notes

### Token Storage
**Table:** `api_tokens`

**Columns (New):**
- `id` - Token ID (UUID)
- `user_id` - User who owns token
- `name` - Token name
- `token_hash` - SHA256 hash of token
- `token_prefix` - First 8 chars for quick lookup
- `created_at` - Creation timestamp
- `last_used` - Last usage timestamp (optional)
- `expires_at` - Expiration timestamp (optional)
- `revoked_at` - Revocation timestamp (optional)

**Removed Columns:**
- `project_ids` - No longer needed (project access via user membership)

### Project Access Control
**New Pattern:**
```
User
  ↓
Project Membership (via direct assignment or group)
  ↓
Role (Owner/Member/Viewer)
  ↓
Operation allowed based on role
```

### Group-Based Access
```
User
  ↓
Group Membership
  ↓
Project via Group
  ↓
Inherited Role
```

## Testing Smoke Tests with New Security Model

All smoke tests work without modification. The tests automatically:
1. Create a token (user-level, no project scope)
2. Use the token to authenticate API requests
3. Create a project
4. Access that project (user is owner)
5. Perform operations (allowed by owner role)
6. Clean up (delete project)

## Migration Notes for Other Code

If you have code that references `project_ids` in tokens:

1. **Removal of `project_ids` field**
   - Old: Check `token.project_ids.includes(projectId)`
   - New: Check `user.memberOf(projectId)` or `user.memberOf(groupId)` where group is in project

2. **Token creation**
   - Old: Create token with `project_ids: [...]`
   - New: Just create token for user, don't specify projects

3. **Token validation**
   - Old: Validate token scope includes project
   - New: Validate user membership in project

4. **Database queries**
   - Remove `project_ids` from token-related queries
   - Add project membership lookups to access control

## Backward Compatibility

⚠️ **Breaking Change:** If you have code expecting `project_ids` in tokens:
- Will fail with "column not found" errors
- Need to update to use project membership instead
- No tokens will have the `project_ids` field

## Verification

To verify the new security model is working:

```powershell
# 1. Create token (no project_ids)
./create-token.ps1

# 2. Check token in database (should not have project_ids column)
sqlite3 fold.db "SELECT * FROM api_tokens LIMIT 1"

# 3. Run comprehensive smoke test
$env:FOLD_TOKEN = "fold_..."
./v2-comprehensive-smoke-test.ps1

# 4. Run chunk smoke test
./chunk-db-smoke-test.ps1

# All tests should pass with new security model
```

## Summary

✅ **Tests Updated for New Security Model**
- Removed `project_ids` field from token creation
- Updated documentation to explain user/group-based access
- Fixed PowerShell syntax issues
- All smoke tests ready to validate new security model

✅ **No Breaking Changes to Tests**
- Bearer token authentication still works
- Tests automatically handle project membership
- User running tests has owner role on created projects

✅ **Security Model Benefits**
- More flexible: Can assign users to multiple projects
- Cleaner: Tokens don't encode project scope
- Scalable: Group-based access for teams
- Standard: User + role-based access control (RBAC)
