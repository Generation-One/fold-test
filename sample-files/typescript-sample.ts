/**
 * Sample TypeScript file for testing AST-based chunking.
 *
 * Contains classes, interfaces, functions, and type definitions
 * that should be extracted as separate chunks.
 */

import { EventEmitter } from 'events';

/**
 * User interface defining the shape of user data.
 */
export interface User {
    id: string;
    name: string;
    email: string;
    role: UserRole;
    createdAt: Date;
    updatedAt: Date;
}

/**
 * Available user roles in the system.
 */
export type UserRole = 'admin' | 'editor' | 'viewer' | 'guest';

/**
 * Configuration options for the user service.
 */
export interface UserServiceConfig {
    apiUrl: string;
    timeout: number;
    retryAttempts: number;
}

/**
 * User service for managing user operations.
 */
export class UserService extends EventEmitter {
    private users: Map<string, User> = new Map();
    private config: UserServiceConfig;

    constructor(config: UserServiceConfig) {
        super();
        this.config = config;
    }

    /**
     * Create a new user with the given data.
     */
    async createUser(data: Omit<User, 'id' | 'createdAt' | 'updatedAt'>): Promise<User> {
        const user: User = {
            ...data,
            id: crypto.randomUUID(),
            createdAt: new Date(),
            updatedAt: new Date(),
        };

        this.users.set(user.id, user);
        this.emit('user:created', user);
        return user;
    }

    /**
     * Get a user by their ID.
     */
    async getUser(id: string): Promise<User | null> {
        return this.users.get(id) ?? null;
    }

    /**
     * Update an existing user.
     */
    async updateUser(id: string, data: Partial<User>): Promise<User | null> {
        const user = this.users.get(id);
        if (!user) return null;

        const updated: User = {
            ...user,
            ...data,
            updatedAt: new Date(),
        };

        this.users.set(id, updated);
        this.emit('user:updated', updated);
        return updated;
    }

    /**
     * Delete a user by their ID.
     */
    async deleteUser(id: string): Promise<boolean> {
        const deleted = this.users.delete(id);
        if (deleted) {
            this.emit('user:deleted', id);
        }
        return deleted;
    }

    /**
     * List all users with optional filtering.
     */
    async listUsers(filter?: { role?: UserRole }): Promise<User[]> {
        let users = Array.from(this.users.values());

        if (filter?.role) {
            users = users.filter(u => u.role === filter.role);
        }

        return users;
    }
}

/**
 * Authentication service for handling user login/logout.
 */
export class AuthService {
    private tokens: Map<string, string> = new Map();

    /**
     * Authenticate a user with credentials.
     */
    async login(email: string, password: string): Promise<string | null> {
        // Simplified auth logic
        if (!email || !password) return null;

        const token = crypto.randomUUID();
        this.tokens.set(email, token);
        return token;
    }

    /**
     * Logout a user and invalidate their token.
     */
    async logout(email: string): Promise<void> {
        this.tokens.delete(email);
    }

    /**
     * Validate an authentication token.
     */
    async validateToken(token: string): Promise<boolean> {
        return Array.from(this.tokens.values()).includes(token);
    }
}

/**
 * Format a date to ISO string.
 */
export function formatDate(date: Date): string {
    return date.toISOString();
}

/**
 * Parse a date from ISO string.
 */
export function parseDate(dateStr: string): Date {
    return new Date(dateStr);
}

/**
 * Check if a user has admin privileges.
 */
export function isAdmin(user: User): boolean {
    return user.role === 'admin';
}

/**
 * Generate a random ID.
 */
export function generateId(): string {
    return crypto.randomUUID();
}

/**
 * Check if a user has at least editor privileges.
 */
export function canEdit(user: User): boolean {
    return user.role === 'admin' || user.role === 'editor';
}

// Default export
export default UserService;
