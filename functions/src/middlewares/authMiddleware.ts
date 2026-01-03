import { Request, Response, NextFunction } from 'express';
import * as jwt from 'jsonwebtoken';
import { defineString } from 'firebase-functions/params';
import { db } from '../config/firebase';

const jwtSecret = defineString('JWT_SECRET', { default: 'your-default-jwt-secret' });

declare global {
  namespace Express {
    interface Request {
      user?: {
        userId: string;
        email: string;
        role: string;
        /** ⬇️ carry empid from JWT so routes can use it */
        empid?: string | null;
      };
    }
  }
}

interface JwtPayload {
  userId: string;
  email: string;
  role: string;
  /** ⬇️ present in your issued tokens */
  empid?: string | null;
  iat: number;
  exp: number;
}

function getToken(req: Request): string | null {
  const h = (req.headers.authorization || req.headers.Authorization || '') as string;
  if (typeof h === 'string') {
    const [scheme, token] = h.split(' ');
    if (scheme && token && /^Bearer$/i.test(scheme)) return token.trim();
  }
  if (req.headers['x-access-token']) return String(req.headers['x-access-token']).trim();
  return null;
}

export const authMiddleware = async (req: Request, res: Response, next: NextFunction): Promise<Response | void> => {
  try {
    const token = getToken(req);
    if (!token) return res.status(401).json({ message: 'No token provided' });

    return new Promise((resolve) => {
      jwt.verify(token, jwtSecret.value(), async (err, decoded) => {
        if (err) {
          res.status(403).json({ message: 'Invalid or expired token' });
          return resolve();
        }

        const jwtPayload = decoded as JwtPayload;

        try {
          const userDoc = await db.collection('users').doc(jwtPayload.userId).get();
          if (!userDoc.exists) {
            res.status(401).json({ message: 'User not found' });
            return resolve();
          }

          // ⬇️ include empid, if present in token
          req.user = {
            userId: jwtPayload.userId,
            email: jwtPayload.email,
            role: jwtPayload.role,
            empid: jwtPayload.empid ?? null,
          };

          next();
          resolve();
        } catch (error) {
          console.error('Error checking user existence:', error);
          res.status(500).json({ message: 'Internal server error' });
          resolve();
        }
      });
    });
  } catch (error) {
    console.error('Auth middleware error:', error);
    res.status(401).json({ error: 'Invalid or expired token' });
    return;
  }
};

export const roleMiddleware = (roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction): Response | void => {
    if (!req.user) return res.status(401).json({ error: 'Not authenticated' });
    if (!roles.includes(req.user.role)) return res.status(403).json({ error: 'Not authorized' });
    next();
  };
};

export const verifyToken = authMiddleware;
export const isAdmin = (req: Request, res: Response, next: NextFunction) =>
  roleMiddleware(['admin'])(req, res, next);
