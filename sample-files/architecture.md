# Application Architecture

## Overview

This document describes the architecture of the user management system, including authentication, data persistence, and API design.

## Components

### 1. Database Layer (`database.ts`)

The foundation of the system, providing:
- Connection pooling for efficient resource usage
- Unified query interface
- Transaction support for data integrity

All services depend on this layer for data persistence.

### 2. Authentication Service (`auth-service.ts`)

Handles all authentication concerns:
- User login with email/password
- JWT token generation and validation
- Token refresh mechanism
- Session revocation

Depends on: Database

### 3. User Service (`user-service.ts`)

Manages user accounts and preferences:
- User CRUD operations
- Profile management
- Preference settings (theme, notifications, language)

Depends on: Database, AuthService

### 4. API Routes (`api-routes.ts`)

RESTful API endpoints exposing services:
- `/auth/*` - Authentication endpoints
- `/users/*` - User management endpoints

Depends on: UserService, AuthService, Database

## Data Flow

1. Client sends request to API endpoint
2. Auth middleware validates token via AuthService
3. Route handler calls appropriate service
4. Service performs business logic
5. Database layer persists changes
6. Response returned to client

## Security Considerations

- All passwords hashed with bcrypt
- JWT tokens expire after 24 hours
- Refresh tokens for seamless re-authentication
- Token revocation on user deletion
