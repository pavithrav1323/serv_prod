import { Router } from 'express';
import { verifyToken } from '../middlewares/authMiddleware';
import {
  trackingCheckIn,
  trackingAppendPos,
  trackingCheckOut,
  trackingGetDay,
} from '../controllers/trackingController';

const router = Router();

router.post('/check-in', verifyToken, trackingCheckIn);
router.post('/pos', verifyToken, trackingAppendPos);
router.post('/check-out', verifyToken, trackingCheckOut);
router.get('/day', verifyToken, trackingGetDay);

export default router;
