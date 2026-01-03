import { Router } from 'express';
import * as attendanceController from '../controllers/attendanceController';
import { authMiddleware } from '../middlewares/authMiddleware';
const router = Router();

// Apply auth middleware to all routes
router.use(authMiddleware);

router.get('/live', attendanceController.getLiveAttendance);
router.get('/approvals', attendanceController.listApprovals);
router.post('/approvals/decision', attendanceController.decideApproval);
router.get('/my-requests', attendanceController.listMyRequests);
router.get('/employee/:empid', attendanceController.getEmployeeAttendance);
router.get('/monthly/:empid/:year/:month', attendanceController.getMonthlySummary);
router.get('/roster', attendanceController.getDailyRoster);
router.get('/range-summary', attendanceController.getRangeSummary);
router.get('/month-view/:empid/:year/:month', attendanceController.getMonthView);
router.post('/check-in', attendanceController.checkIn);
router.post('/check-out', attendanceController.checkOut);
router.get('/other-location', attendanceController.listOtherLocationEvents);
router.post('/other-location/decision', attendanceController.decideOtherLocationEvent);
router.get('/other-location/ping', (_req, res) => res.json({ ok: true }));
router.get('/me', attendanceController.getCurrentUser);
router.get('/summary/:empid/:year/:month', attendanceController.getMonthlySummary);

export default router;