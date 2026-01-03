import { Router } from 'express';
import { authMiddleware } from '../middlewares/authMiddleware';
import { getRequestDetails } from '../controllers/employeedetailcontroller';

const router = Router();

/**
 * GET /api/attendance/request-details
 * Query: id&src=attendance|other_location  OR  empid&date=YYYY-MM-DD
 */
router.get('/request-details', authMiddleware, getRequestDetails);

export default router;
