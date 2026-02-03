# User Guide

This guide explains how to use the sample project.

## Getting Started

First, ensure you have Rust installed on your system.
You can install it from https://rustup.rs/.

## Building

Run the following command to build the project:

```bash
cargo build --release
```

## Running

Execute the binary:

```bash
./target/release/sample-project
```

## Configuration

The project uses environment variables for configuration.
Set them before running:

```bash
export HOST=0.0.0.0
export PORT=8080
```

## API Reference

### Functions

- `add(a, b)` - Add two numbers
- `multiply(a, b)` - Multiply two numbers

### Structs

- `Counter` - A simple counter with increment functionality
- `AppConfig` - Application configuration

## Troubleshooting

### Build fails

Make sure you have the latest Rust version:

```bash
rustup update
```

### Port already in use

Change the port in your environment:

```bash
export PORT=8081
```
