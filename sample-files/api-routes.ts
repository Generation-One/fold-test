/**
 * API Routes
 *
 * Express router definitions for the REST API.
 * Integrates UserService and AuthService for user management endpoints.
 *
 * Routes:
 * - POST /auth/login - User authentication
 * - POST /auth/refresh - Token refresh
 * - GET /users/:id - Get user profile
 * - PUT /users/:id/preferences - Update preferences
 * - DELETE /users/:id - Delete user account
 */

import { Router, Request, Response } from 'express';
import { UserService } from './user-service';
import { AuthService } from './auth-service';
import { Database } from './database';

const db = new Database({
  host: 'localhost',
  port: 5432,
  database: 'myapp',
  user: 'app',
  password: 'secret',
  poolSize: 10
});

const authService = new AuthService(db);
const userService = new UserService(authService, db);

const router = Router();

// Authentication routes
router.post('/auth/login', async (req: Request, res: Response) => {
  try {
    const token = await authService.login(req.body);
    res.json({ token: token.token, expiresAt: token.expiresAt });
  } catch (err: any) {
    res.status(401).json({ error: err.message });
  }
});

router.post('/auth/refresh', async (req: Request, res: Response) => {
  try {
    const { refreshToken } = req.body;
    const token = await authService.refreshToken(refreshToken);
    res.json({ token: token.token, expiresAt: token.expiresAt });
  } catch (err: any) {
    res.status(401).json({ error: err.message });
  }
});

// User routes (require authentication)
router.get('/users/:id', authMiddleware, async (req: Request, res: Response) => {
  const user = await userService.getUser(req.params.id);
  if (!user) {
    return res.status(404).json({ error: 'User not found' });
  }
  res.json(user);
});

router.put('/users/:id/preferences', authMiddleware, async (req: Request, res: Response) => {
  try {
    await userService.updatePreferences(req.params.id, req.body);
    res.json({ success: true });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

router.delete('/users/:id', authMiddleware, async (req: Request, res: Response) => {
  try {
    await userService.deleteUser(req.params.id);
    res.json({ success: true });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

// Middleware for auth validation
async function authMiddleware(req: Request, res: Response, next: any) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const valid = await authService.validateToken(token);
  if (!valid) {
    return res.status(401).json({ error: 'Invalid token' });
  }

  next();
}

export default router;
