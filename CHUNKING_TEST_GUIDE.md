# Fold v2 File Chunking Test Guide

Complete guide to testing file indexing, AST-based chunking, vectorization, and chunk-level search in Fold v2.

## Overview

Fold v2 introduces AST-based chunked indexing that breaks files into semantic units (functions, classes, methods) and indexes each chunk separately. This enables fine-grained search at the function level rather than whole-file search.

### Key Features Being Tested

1. **File Indexing** - Reading files and creating memories
2. **AST-based Chunking** - Using tree-sitter to extract functions, classes, methods
3. **Chunk Vectorization** - Generating embeddings for each chunk
4. **Chunk Storage** - Storing chunks in SQLite + embeddings in Qdrant
5. **Chunk-level Search** - Finding and returning matched chunks with line numbers
6. **Multi-language Support** - Rust, TypeScript, Python, Markdown, etc.
7. **Search Accuracy** - Function name search, semantic search, cross-file search

## Test Files Created

### 1. `file_chunking_tests.rs` - Contract-Based Tests

Location: `srv/tests/file_chunking_tests.rs`

**Test Categories:** 70+ tests validating chunking behavior

#### Chunk Structure Tests
- `test_chunk_model_structure()` - Verify chunk fields
- `test_chunk_match_response_structure()` - Validate search response format

#### Language-Specific Chunking
- `test_rust_function_chunking()` - Rust AST: functions, structs, impls
- `test_typescript_class_chunking()` - TS AST: classes, interfaces, methods
- `test_python_function_chunking()` - Python AST: classes, functions
- `test_markdown_heading_chunking()` - Markdown: heading-based chunks

#### Chunk Metadata Validation
- `test_chunk_line_numbers_accuracy()` - Verify start_line/end_line
- `test_chunk_node_type_values()` - Verify node types (function, class, etc.)
- `test_chunk_has_content_hash()` - Check content deduplication
- `test_chunk_parent_memory_reference()` - Verify memory_id links

#### Chunk Size Constraints
- `test_chunk_minimum_size_constraint()` - Min 3 lines
- `test_chunk_maximum_size_constraint()` - Max 200 lines
- `test_chunk_splitting_for_large_functions()` - Large chunks split into 50-line pieces

#### Vectorization Tests
- `test_each_chunk_gets_embedding()` - Every chunk has vector
- `test_chunk_qdrant_payload_structure()` - Verify Qdrant metadata
- `test_chunk_similarity_score_in_search()` - Score 0.0-1.0

#### Chunk-Level Search
- `test_search_with_include_chunks_parameter()` - include_chunks=true parameter
- `test_search_returns_matched_chunks_when_enabled()` - Response includes matched_chunks
- `test_chunk_only_search_results()` - Find chunks without memory match
- `test_chunk_snippet_preview_in_results()` - Snippet in results
- `test_chunks_ranked_by_similarity()` - Chunks ranked by score

#### Linking and Relationships
- `test_chunks_linked_to_parent_memory()` - memory_id reference
- `test_chunks_maintain_order_within_memory()` - Ordered by start_line

#### File Type Support
- `test_supported_file_extensions()` - 23+ supported types
- `test_unsupported_file_types_fallback_to_line_chunking()` - Fallback strategy

#### Update and Deduplication
- `test_chunks_deleted_on_file_update()` - Re-indexing replaces chunks
- `test_chunks_not_duplicated_with_same_content()` - Deterministic chunk IDs

#### Search Accuracy
- `test_function_name_search_finds_function_chunk()` - Name matching
- `test_semantic_search_finds_related_chunks()` - Semantic matching
- `test_chunk_search_precision()` - More precise than file search

#### Performance and Scaling
- `test_large_file_chunking_performance()` - 10K line files
- `test_concurrent_file_indexing()` - Parallel indexing (4 concurrent)
- `test_chunk_storage_efficiency()` - Storage size per chunk

### 2. `file_chunking_http_tests.rs` - HTTP Integration Tests

Location: `srv/tests/file_chunking_http_tests.rs`

**Test Categories:** End-to-end file indexing and search workflows

#### File Indexing Tests
- `test_http_index_rust_file_creates_chunks()` - Index Rust file, verify chunking
- `test_http_index_typescript_file_creates_chunks()` - Index TypeScript file

#### Chunk-Level Search Tests
- `test_http_chunk_search_with_include_chunks()` - Enable chunk search, verify response
- `test_http_find_function_by_name_in_chunks()` - Find specific function by name
- `test_http_chunk_line_numbers_accurate()` - Verify line numbers in results

#### Multi-File Search
- `test_http_search_across_multiple_files_chunks()` - Search spans multiple files

#### Vectorization Tests
- `test_http_chunks_are_vectorized()` - Chunks are searchable (vectorized)

## Chunk Structure Reference

### Chunk Database Record
```sql
CREATE TABLE chunks (
    id TEXT PRIMARY KEY,              -- Deterministic: SHA256(memory_id + content_hash)
    memory_id TEXT NOT NULL,          -- Parent file/memory ID
    project_id TEXT NOT NULL,         -- Project scope
    content TEXT NOT NULL,            -- Code/text content
    content_hash TEXT NOT NULL,       -- SHA256 for deduplication
    start_line INTEGER NOT NULL,      -- 1-indexed start line
    end_line INTEGER NOT NULL,        -- 1-indexed end line
    start_byte INTEGER DEFAULT 0,     -- Byte offset start
    end_byte INTEGER DEFAULT 0,       -- Byte offset end
    node_type TEXT NOT NULL,          -- function, class, struct, method, etc.
    node_name TEXT,                   -- Extracted name (function name, class name)
    language TEXT NOT NULL,           -- Programming language (rust, typescript, etc.)
    created_at TEXT NOT NULL,         -- Creation timestamp
    updated_at TEXT NOT NULL          -- Last update timestamp
);
```

### Chunk in Search Response
```json
{
    "id": "chunk-uuid",
    "node_type": "function",
    "node_name": "handle_request",
    "start_line": 42,
    "end_line": 68,
    "score": 0.95,
    "snippet": "pub async fn handle_request(...) {"
}
```

### Search Result with Chunks
```json
{
    "id": "memory-uuid",
    "title": "HTTP Handlers",
    "score": 0.92,
    "source": "file",
    "matched_chunks": [
        {
            "id": "chunk-1",
            "node_type": "function",
            "node_name": "handle_request",
            "start_line": 42,
            "end_line": 68,
            "score": 0.95,
            "snippet": "pub async fn handle_request(req: Request) -> Response {"
        }
    ]
}
```

## Supported Languages for AST Chunking

| Language | Parser | Node Types | Status |
|----------|--------|-----------|--------|
| **Rust** | tree-sitter-rust | function, struct, enum, trait, impl, module, macro | ✅ Full |
| **TypeScript** | tree-sitter-typescript | class, interface, function, method, type, export | ✅ Full |
| **JavaScript** | tree-sitter-javascript | class, function, method, export | ✅ Full |
| **Python** | tree-sitter-python | function, class, decorated | ✅ Full |
| **Go** | tree-sitter-go | function, method, type | ✅ Full |
| **Markdown** | regex (heading-based) | h1-h6 headings | ✅ Heading-based |
| **Plain Text** | line-based | paragraphs | ✅ Paragraph-based |
| **Java, Ruby, PHP, etc.** | fallback | lines (50-line chunks) | ⚠️ Line-based |

## How to Run Tests

### Contract Tests (No Server Required)

```bash
cd srv

# Run all chunking contract tests
cargo test --test file_chunking_tests -- --nocapture

# Run specific test category
cargo test --test file_chunking_tests rust_function_chunking -- --nocapture
cargo test --test file_chunking_tests typescript_class_chunking -- --nocapture
cargo test --test file_chunking_tests chunk_line_numbers_accuracy -- --nocapture

# List all tests
cargo test --test file_chunking_tests --lib -- --list
```

### HTTP Integration Tests (Server Required)

```bash
# Start server
cd srv
cargo run &

# In another terminal, set environment
export FOLD_TOKEN=$(cd ../test && powershell .\create-token.ps1)
export FOLD_URL="http://localhost:8765"

# Run HTTP chunking tests
cd srv
cargo test --test file_chunking_http_tests -- --nocapture --include-ignored

# Run specific test
cargo test --test file_chunking_http_tests test_http_index_rust_file_creates_chunks -- --nocapture --include-ignored
```

## Expected Test Results

### Rust File Indexing
```
File: src/handlers.rs
Expected Chunks:
  1. Struct "HttpHandler" (lines 1-3)
  2. Impl block (lines 5-12) or individual methods
  3. Method "new" (lines 6-9)
  4. Method "handle_request" (lines 11-20)
  5. Method "handle_get" (lines 22-24)
  6. Method "handle_post" (lines 26-28)
```

### TypeScript File Indexing
```
File: src/services/user.ts
Expected Chunks:
  1. Interface "UserRequest" (lines 1-3)
  2. Class "UserService" (lines 5-27) or methods
  3. Method "handleRequest" (lines 7-10)
  4. Method "processAction" (lines 12-21)
  5. Method "handleRead" (lines 23-25)
  6. Method "handleWrite" (lines 27-29)
  7. Function "createService" (line 31)
```

## Chunk Search Behavior

### Scenario: Search for "authenticate"

**File Content:**
```rust
pub fn authenticate_user(username: &str, password: &str) -> Result<User> {
    validate_credentials(username, password)?;
    create_session(&user)?;
    Ok(user)
}

pub fn validate_credentials(username: &str, password: &str) -> Result<User> {
    // Verify against database
    let user = get_user_from_db(username)?;
    if bcrypt::verify(password, &user.password_hash)? {
        Ok(user)
    } else {
        Err("Invalid password")
    }
}
```

**Chunks Created:**
```
Chunk 1: authenticate_user (function, lines 1-5)
Chunk 2: validate_credentials (function, lines 7-16)
```

**Search Results with include_chunks=true:**
```json
{
    "results": [
        {
            "id": "memory-123",
            "title": "Authentication Module",
            "matched_chunks": [
                {
                    "id": "chunk-1",
                    "node_name": "authenticate_user",
                    "node_type": "function",
                    "start_line": 1,
                    "end_line": 5,
                    "score": 0.96,
                    "snippet": "pub fn authenticate_user(username: &str, password: &str)..."
                },
                {
                    "id": "chunk-2",
                    "node_name": "validate_credentials",
                    "node_type": "function",
                    "start_line": 7,
                    "end_line": 16,
                    "score": 0.88,
                    "snippet": "pub fn validate_credentials(username: &str, password: &str)..."
                }
            ]
        }
    ]
}
```

## Testing Checklist

### Preparation
- [ ] Ensure Fold server v2 is running
- [ ] Qdrant database is running
- [ ] Tree-sitter parsers are available for target languages
- [ ] FOLD_TOKEN environment variable set
- [ ] FOLD_URL configured (default: http://localhost:8765)

### Contract Tests
- [ ] All 70+ chunk structure tests pass
- [ ] Language-specific chunking tests pass
- [ ] Metadata accuracy tests pass
- [ ] Line number validation passes
- [ ] Size constraint tests pass

### HTTP Integration Tests
- [ ] Rust file indexing creates chunks
- [ ] TypeScript file indexing creates chunks
- [ ] Chunk search with include_chunks=true works
- [ ] Function name search finds correct chunks
- [ ] Multi-file search spans all chunks
- [ ] Chunks are vectorized and searchable

### Search Accuracy Tests
- [ ] Search "authenticate" finds functions with "auth" in name/content
- [ ] Function names match exactly with high scores (>0.9)
- [ ] Semantic search finds related functions (>0.8)
- [ ] Line numbers in results are accurate
- [ ] Snippets show actual code from that range

## Common Issues and Solutions

### Issue: No chunks in search results

**Symptoms:** Search works but `matched_chunks` is empty

**Possible Causes:**
1. File hasn't been indexed yet (wait 2-3 seconds)
2. Chunks not vectorized (Qdrant not running)
3. `include_chunks` parameter missing in search request

**Solution:**
```powershell
# Verify chunks created
# Check database: SELECT COUNT(*) FROM chunks WHERE memory_id = ?;

# Re-index file (update memory)
# Verify Qdrant is running: curl http://localhost:6333/health

# Use include_chunks in search:
$search = @{ query = "..."; include_chunks = $true } | ConvertTo-Json
```

### Issue: Line numbers don't match code

**Symptoms:** matched_chunks have start_line/end_line that don't correspond to actual code

**Possible Causes:**
1. File has CRLF line endings (Windows vs Unix)
2. Tabs vs spaces affecting line count
3. Multi-line strings confusing AST parser

**Solution:**
```powershell
# Normalize line endings before indexing
# Convert CRLF to LF: (Get-Content file.rs) -replace "`r`n", "`n" | Set-Content file.rs

# For Markdown, heading detection may skip code blocks
```

### Issue: Large functions not split into chunks

**Symptoms:** Function >200 lines shows as single chunk

**Possible Causes:**
1. Tree-sitter parser sees function as one node
2. Chunking size limit not enforced

**Solution:**
```
Expected: Functions >200 lines split into 50-line chunks
Check: config.max_chunk_lines (should be 200)
Check: line_chunk_size (should be 50)
```

### Issue: Python/Java files show as line-based chunks

**Symptoms:** Chunks are generic "lines" type instead of functions/classes

**Possible Causes:**
1. Tree-sitter parser not available for language
2. Language detection failed
3. File has syntax errors

**Solution:**
```rust
// Check language detection
let language = Self::detect_language("file.java");  // Should return "java"

// Check parser availability
let parser = create_parser("java");  // Should succeed

// Verify file syntax is valid
```

## Performance Expectations

### Indexing Performance
- **Small files** (< 1KB): < 100ms per file
- **Medium files** (1-10KB): 200-500ms per file
- **Large files** (10-100KB): 1-2 seconds per file
- **Concurrency**: 4 files indexed in parallel by default

### Chunk Creation
- **5KB Rust file**: ~4-6 chunks (functions, structs)
- **10KB TypeScript file**: ~8-12 chunks (classes, methods)
- **100KB file**: Should be split or handled with overlap

### Search Performance
- **With chunks**: ~10-50ms per query (more precise)
- **Without chunks**: ~5-20ms per query (broader)
- Chunk matching adds ~5-30% overhead for accuracy gain

## Next Steps

### When All Tests Pass
1. Run full integration test suite
2. Performance test with real project files
3. Test edge cases:
   - Very large files (>1MB)
   - Complex nested structures
   - Mixed language files (markdown with code blocks)
   - Files with syntax errors

### Planned Improvements
1. [ ] Chunk-based autocomplete
2. [ ] Chunk relationship graph (which functions call which)
3. [ ] Chunk-level diff tracking
4. [ ] Fine-grained change detection
5. [ ] Chunk-level access control

## References

- See `src/models/chunk.rs` for chunk model
- See `src/services/chunker.rs` for AST parsing
- See `src/services/indexer.rs` for file indexing
- See `schema.sql` for chunk table definition
