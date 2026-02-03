/**
 * Sample TypeScript file for Fold indexing tests.
 * This file demonstrates authentication patterns.
 */

interface User {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'member';
}

interface AuthToken {
  token: string;
  expiresAt: Date;
  userId: string;
}

/**
 * Validates a JWT token and returns the user if valid.
 */
export async function validateToken(token: string): Promise<User | null> {
  // Decode and verify JWT
  const payload = decodeJwt(token);

  if (!payload || isExpired(payload.exp)) {
    return null;
  }

  // Fetch user from database
  const user = await getUserById(payload.sub);
  return user;
}

/**
 * Creates a new authentication session for a user.
 */
export async function createSession(user: User): Promise<AuthToken> {
  const token = generateJwt({
    sub: user.id,
    email: user.email,
    role: user.role,
  });

  return {
    token,
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
    userId: user.id,
  };
}

// Helper functions (stubs for testing)
function decodeJwt(token: string): any { return {}; }
function isExpired(exp: number): boolean { return false; }
async function getUserById(id: string): Promise<User | null> { return null; }
function generateJwt(payload: object): string { return ''; }
