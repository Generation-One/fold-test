/**
 * User Service
 *
 * Core service for user management including CRUD operations,
 * profile management, and user preferences.
 *
 * Dependencies:
 * - auth-service.ts for authentication
 * - database.ts for data persistence
 */

import { AuthService } from './auth-service';
import { Database } from './database';

export interface User {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'user' | 'guest';
  createdAt: Date;
  preferences: UserPreferences;
}

export interface UserPreferences {
  theme: 'light' | 'dark';
  notifications: boolean;
  language: string;
}

export class UserService {
  constructor(
    private auth: AuthService,
    private db: Database
  ) {}

  async createUser(email: string, name: string): Promise<User> {
    const id = crypto.randomUUID();
    const user: User = {
      id,
      email,
      name,
      role: 'user',
      createdAt: new Date(),
      preferences: { theme: 'light', notifications: true, language: 'en' }
    };
    await this.db.insert('users', user);
    return user;
  }

  async getUser(id: string): Promise<User | null> {
    return this.db.findById('users', id);
  }

  async updatePreferences(userId: string, prefs: Partial<UserPreferences>): Promise<void> {
    const user = await this.getUser(userId);
    if (!user) throw new Error('User not found');
    user.preferences = { ...user.preferences, ...prefs };
    await this.db.update('users', userId, user);
  }

  async deleteUser(userId: string): Promise<void> {
    await this.auth.revokeAllTokens(userId);
    await this.db.delete('users', userId);
  }
}
