// routes/report.ts
import { Router } from 'express';
import * as ctrl from '../controllers/reportController';
import { authMiddleware, roleMiddleware } from '../middlewares/authMiddleware';

const router = Router();

// All report routes require auth
router.use(authMiddleware);

/**
 * @swagger
 * tags:
 *   - name: Reports
 *     description: Report scheduler
 *
 * components:
 *   schemas:
 *     ReportSchedule:
 *       type: object
 *       required: [name, reportType, templateId, recipient, scheduleTime]
 *       properties:
 *         id: { type: string }
 *         name: { type: string }
 *         reportType:
 *           type: string
 *           enum: [Check-In, Check-Out, Present, Absent, Late Check-In]
 *         templateId: { type: string }
 *         recipient:
 *           type: string
 *           format: email
 *         scheduleTime: { type: string, description: 'Cron or HH:mm' }
 *         createdAt: { type: string, format: date-time }
 */

// POST /api/reports
router.post('/', roleMiddleware(['admin']), ctrl.createSchedule);

// GET /api/reports
router.get('/', roleMiddleware(['admin']), ctrl.listSchedules);

// POST /api/reports/:id/run
router.post('/:id/run', roleMiddleware(['admin']), ctrl.runNow);

// DELETE /api/reports/:id
router.delete('/:id', roleMiddleware(['admin']), ctrl.deleteSchedule);

export default router;
