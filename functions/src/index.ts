// functions/src/index.ts
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { onRequest } from 'firebase-functions/v2/https';
import { defineString } from 'firebase-functions/params';

// ✅ Ensure firebase-admin is initialized exactly once
import * as admin from 'firebase-admin';
if (!admin.apps.length) {
  admin.initializeApp();
}

// Shared Firebase (single source of truth)
import { db } from './config/firebase';

// Routes
import authRoutes from './routes/auth';
import companyRoutes from './routes/company';
import employeeRoutes from './routes/employees';
import attendanceRoutes from './routes/attendance';
import leaveRoutes from './routes/leave';
import leaveTypeRoutes from './routes/leaveTypes';
import officeLocationRoutes from './routes/officeLocation';
import uploadRoutes from './routes/upload';
import reportRoutes from './routes/report';
import rewardRoutes from './routes/reward';
import feedbackRoutes from './routes/feedbackRoutes';
import eventRoutes from './routes/event';
import shiftRoutes from './routes/shift';
import taskRoutes from './routes/task';
import trackingRoutes from './routes/tracking';
import liveEmployeeDetailsRouter from './routes/liveEmployeeDetails';
import * as authController from './controllers/authController';
import reasonsRouter from './routes/reasons';
import overtimeRoutes from "./routes/overtime";
import adminRoutes from "./routes/admin";
// -------------------- App setup --------------------
const app = express();

// Params (do NOT call .value() at module load for function options)
const REGION = defineString('REGION', { default: 'us-central1' });
const CORS_ORIGIN = defineString('CORS_ORIGIN', { default: 'http://localhost:4500' });

// Body parsers
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Tiny logger
app.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
  next();
});

// --------- Global no-cache (avoid 304 / empty bodies) ----------
app.set('etag', false);
app.use((req, res, next) => {
  res.setHeader('Cache-Control', 'private, no-store, no-cache, must-revalidate, proxy-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  // auth changes the response shape
  res.setHeader('Vary', 'Authorization');
  next();
});

// CORS — evaluate allowlist at request time
app.use((req, res, next) => {
  const allowList = (CORS_ORIGIN.value() || '*').split(',').map(s => s.trim());

  cors({
    origin(origin, cb) {
      if (!origin) return cb(null, true); // curl/Postman
      if (allowList.includes('*') || allowList.includes(origin)) return cb(null, true);
      return cb(null, false);
    },
    credentials: true,
    optionsSuccessStatus: 200,
  })(req, res, next);
});

// Preflight for all
app.options('*', (_req, res) => res.sendStatus(204));

// Health
app.get('/', (_req, res) => res.send('api1 root ok'));
app.get('/api/health', (_req: Request, res: Response) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// -------------------- API routes (mounted once) --------------------
app.use('/api/auth', authRoutes);
app.use('/api/company', companyRoutes);
app.use('/api/employees', employeeRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/leaves', leaveRoutes);
app.use('/api/leave-types', leaveTypeRoutes);
app.use('/api/office', officeLocationRoutes);
app.use('/api/uploads', uploadRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/rewards', rewardRoutes);
app.use('/api/events', eventRoutes(db));
app.use('/api/feedback', feedbackRoutes(db));
app.use('/api/shifts', shiftRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/tracking', trackingRoutes);
app.use('/api/liveEmployeeDetails', liveEmployeeDetailsRouter);
app.get('/api/me', authController.getMe);
app.get('/api/profile', authController.getMe);
app.use('/api/reasons', reasonsRouter);
app.use("/api/overtime", overtimeRoutes);
app.use("/api/admin", adminRoutes);
// -------------------- 404 + error handlers --------------------
app.use((req, res) => {
  res.status(404).json({
    status: 'error',
    message: 'Route not found',
    path: req.originalUrl,
    method: req.method,
  });
});

interface AppError extends Error {
  statusCode?: number;
  code?: string;
  stack?: string;
}

app.use((err: AppError, _req: Request, res: Response, _next: NextFunction) => {
  console.error('Error:', err);

  if ((err as any).code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({
      status: 'error',
      message: 'File too large. Maximum file size is 5MB.',
    });
  }

  if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
    return res.status(401).json({
      status: 'error',
      message: 'Invalid or expired token',
    });
  }

  if (err.name === 'ValidationError') {
    return res.status(400).json({
      status: 'error',
      message: err.message,
    });
  }

  return res.status(err.statusCode || 500).json({
    status: 'error',
    message: err.message || 'Internal server error',
  });
});

// -------------------- Export as Firebase Function --------------------
export const api = onRequest(
  {
    region: REGION,
    timeoutSeconds: 120,
    memory: '1GiB',
    minInstances: 0,
    maxInstances: 10,
  },
  exports.api = onRequest(app),
);
