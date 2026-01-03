import { Router } from 'express';
import { verifyToken } from '../middlewares/authMiddleware';
import { liveEmployeeDetails } from '../controllers/liveEmployeeDetails.controller';

const router = Router();

// GET /api/liveEmployeeDetails/:empid?dateIso=YYYY-MM-DD
router.get('/:empid', verifyToken, liveEmployeeDetails);

export default router;
