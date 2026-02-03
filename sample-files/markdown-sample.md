# Fold Documentation

This is the main documentation for the Fold semantic memory system.
It provides an overview of the system architecture and usage.

## Overview

Fold is a holographic memory system that stores and retrieves
semantic knowledge for development teams. It uses vector embeddings
to enable natural language search across codebases and documentation.

Key features include:

- Semantic search across code and docs
- Automatic linking between related memories
- LLM-powered summarisation
- Git integration for change tracking

## Installation

### Prerequisites

Before installing Fold, ensure you have:

- Rust 1.75 or later
- Node.js 18 or later (for the UI)
- Docker (for Qdrant)

### Quick Start

1. Clone the repository:

```bash
git clone https://github.com/Generation-One/fold
cd fold
```

2. Start the dependencies:

```bash
docker-compose up -d
```

3. Build and run the server:

```bash
cd srv
cargo run
```

## Configuration

Fold uses environment variables for configuration.
Create a `.env` file with the following:

```env
HOST=127.0.0.1
PORT=8765
DATABASE_PATH=./data/fold.db
QDRANT_URL=http://localhost:6334
GOOGLE_API_KEY=your-api-key
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOST` | Server host | `127.0.0.1` |
| `PORT` | Server port | `8765` |
| `DATABASE_PATH` | SQLite database path | `./data/fold.db` |
| `QDRANT_URL` | Qdrant vector DB URL | `http://localhost:6334` |

## Usage

### API Endpoints

The Fold API provides RESTful endpoints for managing memories.

#### Create a Memory

```bash
curl -X POST http://localhost:8765/api/projects/my-project/memories \
  -H "Content-Type: application/json" \
  -d '{"content": "My memory content", "memory_type": "note"}'
```

#### Search Memories

```bash
curl "http://localhost:8765/api/projects/my-project/search?query=authentication"
```

### MCP Integration

Fold provides an MCP server for integration with AI assistants.
Connect to it using the standard MCP protocol.

## Architecture

### Components

The system consists of several key components:

1. **Server** - Axum-based REST API
2. **Database** - SQLite for metadata
3. **Vector Store** - Qdrant for embeddings
4. **LLM Service** - Multi-provider with fallback

### Data Flow

```
User Query → Embedding → Qdrant Search → Result Ranking → Response
```

## Troubleshooting

### Common Issues

#### Server won't start

Check that:
- Qdrant is running
- Database path is writable
- Environment variables are set

#### Search returns no results

Ensure:
- The project exists
- Memories have been indexed
- Query is not empty

## Contributing

We welcome contributions! Please see CONTRIBUTING.md for guidelines.

## License

MIT License - see LICENSE file for details.
