# Sample Documentation

This is a sample markdown file for testing Fold's indexing capabilities.

## Overview

The Fold system provides semantic knowledge storage with the following features:

- **Holographic Memory**: Store and retrieve knowledge by meaning, not just keywords
- **Git Integration**: Automatic indexing of repository changes
- **Multi-Provider LLM**: Fallback chain for embeddings and summaries

## Architecture

The system consists of three main components:

### 1. Vector Database (Qdrant)

Stores embeddings for semantic search. Each memory is converted to a vector
representation that captures its meaning.

### 2. Metadata Store (SQLite)

Stores memory metadata, relationships, and project configuration.

### 3. API Server (Rust/Axum)

Handles all requests, manages authentication, and coordinates between
the vector database and metadata store.

## Usage Example

```bash
# Search for memories about authentication
curl -X POST http://localhost:8765/projects/my-project/search \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "how does authentication work?"}'
```

## Decision Record

**Decision**: Use Qdrant for vector storage

**Rationale**: Qdrant provides excellent performance for semantic search
operations and has a simple deployment model suitable for self-hosting.

**Alternatives Considered**:
- Pinecone (SaaS dependency)
- Weaviate (more complex)
- pgvector (less feature-rich)
