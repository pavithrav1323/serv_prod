import { Router } from 'express';
import * as ctrl from '../controllers/leaveTypeController';
import { verifyToken, isAdmin, roleMiddleware } from '../middlewares/authMiddleware';

const router = Router();

// employees or admins may read; only admins may create/delete
const isUserOrAdmin = roleMiddleware(['admin', 'employee']);

// Create leave type (admin only)
router.post('/', verifyToken, isAdmin, ctrl.createLeaveType);

// List leave types (admin and employees)
router.get('/', verifyToken, isUserOrAdmin, ctrl.listLeaveTypes);

// Delete leave type (admin only)
router.delete('/:id', verifyToken, isAdmin, ctrl.deleteLeaveType);

export default router;
