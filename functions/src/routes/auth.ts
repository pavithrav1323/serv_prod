import { Router } from 'express';
import * as authController from '../controllers/authController';
import { authMiddleware, roleMiddleware } from '../middlewares/authMiddleware';

const router = Router();

/* ================= Public ================= */
router.post('/register', authController.register);
router.post('/login', authController.login);

// Legacy simple reset (direct change) — expects { email, newPassword }
router.post('/forgot-password', authController.forgotPassword);

// Modern OTP flow
// Public – request Firebase reset email link
router.post('/forgot-password/request-link', authController.requestPasswordResetLink);

/* ================= Protected ================= */
router.use(authMiddleware);

// This fixes your 404: Flutter calls GET /api/auth/me
router.get('/me', authController.getMe);

// Optional profile aliases
router.get('/profile', authController.getProfile);
router.put('/profile', authController.updateProfile);
router.get('/ping', (_req, res) => res.json({ ok: true, scope: 'auth' }));
// Change password (direct) — expects { email, newPassword }
router.post('/change-password', authController.changePassword);

/* ================= Admin-only ================= */
router.post(
  '/admin/create-employee-login',
  roleMiddleware(['admin']),
  authController.createEmployeeLogin
);

router.post(
  '/admin/backfill-employee-logins',
  roleMiddleware(['admin']),
  authController.backfillEmployeesToUsers
);

export default router;
