/**
 * Authentication Service
 *
 * Handles user authentication, token management, and session validation.
 * Works closely with UserService for user verification.
 *
 * Dependencies:
 * - database.ts for token storage
 * - user-service.ts for user lookups
 */

import { Database } from './database';

export interface AuthToken {
  token: string;
  userId: string;
  expiresAt: Date;
  refreshToken: string;
}

export interface LoginCredentials {
  email: string;
  password: string;
}

export class AuthService {
  private tokenExpiry = 24 * 60 * 60 * 1000; // 24 hours

  constructor(private db: Database) {}

  async login(credentials: LoginCredentials): Promise<AuthToken> {
    const user = await this.db.findByEmail('users', credentials.email);
    if (!user) throw new Error('Invalid credentials');

    const passwordValid = await this.verifyPassword(credentials.password, user.passwordHash);
    if (!passwordValid) throw new Error('Invalid credentials');

    return this.createToken(user.id);
  }

  async createToken(userId: string): Promise<AuthToken> {
    const token: AuthToken = {
      token: crypto.randomUUID(),
      userId,
      expiresAt: new Date(Date.now() + this.tokenExpiry),
      refreshToken: crypto.randomUUID()
    };
    await this.db.insert('tokens', token);
    return token;
  }

  async validateToken(token: string): Promise<boolean> {
    const stored = await this.db.findByToken('tokens', token);
    if (!stored) return false;
    return new Date() < stored.expiresAt;
  }

  async revokeAllTokens(userId: string): Promise<void> {
    await this.db.deleteWhere('tokens', { userId });
  }

  async refreshToken(refreshToken: string): Promise<AuthToken> {
    const existing = await this.db.findByRefreshToken('tokens', refreshToken);
    if (!existing) throw new Error('Invalid refresh token');

    await this.db.delete('tokens', existing.token);
    return this.createToken(existing.userId);
  }

  private async verifyPassword(plain: string, hash: string): Promise<boolean> {
    // Implementation uses bcrypt
    return true; // stub
  }
}
