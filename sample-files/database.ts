/**
 * Database Abstraction Layer
 *
 * Provides a unified interface for data persistence operations.
 * Used by all services including UserService and AuthService.
 *
 * Features:
 * - Connection pooling
 * - Query building
 * - Transaction support
 */

export interface QueryOptions {
  limit?: number;
  offset?: number;
  orderBy?: string;
  order?: 'asc' | 'desc';
}

export interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
  poolSize: number;
}

export class Database {
  private pool: any;

  constructor(private config: DatabaseConfig) {
    this.initPool();
  }

  private initPool(): void {
    // Initialize connection pool
    console.log(`Connecting to ${this.config.host}:${this.config.port}`);
  }

  async insert<T>(table: string, data: T): Promise<void> {
    const conn = await this.pool.getConnection();
    try {
      await conn.query(`INSERT INTO ${table} VALUES (?)`, [data]);
    } finally {
      conn.release();
    }
  }

  async findById<T>(table: string, id: string): Promise<T | null> {
    const conn = await this.pool.getConnection();
    try {
      const [rows] = await conn.query(`SELECT * FROM ${table} WHERE id = ?`, [id]);
      return rows[0] || null;
    } finally {
      conn.release();
    }
  }

  async findByEmail<T>(table: string, email: string): Promise<T | null> {
    const conn = await this.pool.getConnection();
    try {
      const [rows] = await conn.query(`SELECT * FROM ${table} WHERE email = ?`, [email]);
      return rows[0] || null;
    } finally {
      conn.release();
    }
  }

  async findByToken<T>(table: string, token: string): Promise<T | null> {
    return this.findById(table, token);
  }

  async findByRefreshToken<T>(table: string, refreshToken: string): Promise<T | null> {
    const conn = await this.pool.getConnection();
    try {
      const [rows] = await conn.query(`SELECT * FROM ${table} WHERE refreshToken = ?`, [refreshToken]);
      return rows[0] || null;
    } finally {
      conn.release();
    }
  }

  async update<T>(table: string, id: string, data: T): Promise<void> {
    const conn = await this.pool.getConnection();
    try {
      await conn.query(`UPDATE ${table} SET ? WHERE id = ?`, [data, id]);
    } finally {
      conn.release();
    }
  }

  async delete(table: string, id: string): Promise<void> {
    const conn = await this.pool.getConnection();
    try {
      await conn.query(`DELETE FROM ${table} WHERE id = ?`, [id]);
    } finally {
      conn.release();
    }
  }

  async deleteWhere(table: string, conditions: Record<string, any>): Promise<void> {
    const conn = await this.pool.getConnection();
    try {
      const where = Object.entries(conditions).map(([k, v]) => `${k} = ?`).join(' AND ');
      const values = Object.values(conditions);
      await conn.query(`DELETE FROM ${table} WHERE ${where}`, values);
    } finally {
      conn.release();
    }
  }

  async transaction<T>(fn: () => Promise<T>): Promise<T> {
    const conn = await this.pool.getConnection();
    try {
      await conn.beginTransaction();
      const result = await fn();
      await conn.commit();
      return result;
    } catch (err) {
      await conn.rollback();
      throw err;
    } finally {
      conn.release();
    }
  }
}
