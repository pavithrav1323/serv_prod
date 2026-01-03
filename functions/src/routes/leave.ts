import { Router } from 'express';
import * as leaveController from '../controllers/leaveController';
import { authMiddleware, roleMiddleware } from '../middlewares/authMiddleware';

const router = Router();

// All /api/leaves require auth
router.use(authMiddleware);

// ============================================
// Leave Requests
// ============================================

/**
 * POST /api/leaves
 * Create a leave request (supports both new and legacy payloads)
 */
router.post('/', leaveController.createLeaveRequest);

/**
 * GET /api/leaves
 * Admin: list all (with filters + pagination)
 */
router.get('/', roleMiddleware(['admin']), leaveController.getAllLeaveRequests);

/**
 * GET /api/leaves/my
 * Current user's leaves (filters optional)
 */
router.get('/my', leaveController.getAllLeaveRequests);

// Legacy alias for clients already calling /mine
router.get('/mine', leaveController.getAllLeaveRequests);

/**
 * GET /api/leaves/pending
 * Admin: pending leaves, optional ?type=
 */
router.get('/pending', roleMiddleware(['admin']), leaveController.getPendingLeaves);

/**
 * GET /api/leaves/balance
 * Current user's balance
 */
router.get('/balance', leaveController.getLeaveBalance);

/**
 * GET /api/leaves/:id
 * View a single leave (self/admin/approver)
 */
router.get('/:id', leaveController.getLeaveRequestById);

// ============================================
// Leave Types Management
// ============================================

/**
 * GET /api/leave-types
 * Get all leave types
 */
router.get('/types/all', roleMiddleware(['admin']), leaveController.getLeaveTypes);

/**
 * POST /api/leave-types
 * Add a new leave type (admin only)
 */
router.post('/types', roleMiddleware(['admin']), leaveController.addLeaveType);

/**
 * DELETE /api/leave-types
 * Delete a leave type (admin only)
 */
router.delete('/types', roleMiddleware(['admin']), leaveController.deleteLeaveType);

// ============================================
// Leave Request Management
// ============================================

/**
 * PUT /api/leaves/:id
 * Admin: approve/reject/cancel (body: { status, notes? })
 * – kept for backward-compat
 */
router.put('/:id', roleMiddleware(['admin']), leaveController.updateLeaveStatus);

/**
 * PUT /api/leaves/:id/status
 * Admin: approve/reject/cancel (same handler)
 */
router.put('/:id/status', roleMiddleware(['admin']), leaveController.updateLeaveStatus);

/**
 * POST /api/leaves/:id/cancel
 * Requester or admin: cancel a pending request
 */
router.post('/:id/cancel', leaveController.cancelLeaveRequest);

/**
 * DELETE /api/leaves/:id
 * Admin: delete a request
 */
router.delete('/:id', roleMiddleware(['admin']), leaveController.deleteLeave);

export default router;
