import { Router } from 'express';
import * as shiftController from '../controllers/shiftController';
import { verifyToken, isAdmin } from '../middlewares/authMiddleware';

const router = Router();

/**
 * NOTE:
 * This router must be mounted at `/api/shifts` in index.ts:
 *   app.use('/api/shifts', shiftRoutes);
 *
 * Do NOT prefix routes here with /api or /shifts again.
 */

/**
 * @swagger
 * tags:
 *   - name: Shifts
 *     description: CRUD operations for shift templates
 *
 * components:
 *   schemas:
 *     Shift:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *         name:
 *           type: string
 *         startTime:
 *           type: string
 *           pattern: '^(?:[01]\\d|2[0-3]):[0-5]\\d$'
 *         endTime:
 *           type: string
 *           pattern: '^(?:[01]\\d|2[0-3]):[0-5]\\d$'
 *         shiftname:
 *           type: string
 *         createdAt:
 *           type: string
 *           format: date-time
 *         updatedAt:
 *           type: string
 *           format: date-time
 *       required: [id, name, startTime, endTime, shiftname]
 *
 *   parameters:
 *     ShiftId:
 *       in: path
 *       name: id
 *       required: true
 *       schema:
 *         type: string
 *         format: uuid
 */

/**
 * @swagger
 * /api/shifts:
 *   post:
 *     summary: Create a new shift template (Admin only)
 *     tags: [Shifts]
 *     security:
 *       - bearerAuth: []
 */
router.post('/', verifyToken, isAdmin, shiftController.createShift);

/**
 * @swagger
 * /api/shifts:
 *   get:
 *     summary: List all shift templates (Admin only)
 *     tags: [Shifts]
 *     security:
 *       - bearerAuth: []
 */
router.get('/', verifyToken, isAdmin, shiftController.getAllShifts);

/**
 * @swagger
 * /api/shifts/{id}:
 *   get:
 *     summary: Get a single shift template by UUID (Admin only)
 *     tags: [Shifts]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - $ref: '#/components/parameters/ShiftId'
 */
router.get('/:id', verifyToken, isAdmin, shiftController.getShiftById);

/**
 * @swagger
 * /api/shifts/{id}:
 *   put:
 *     summary: Update a shift template (Admin only)
 *     tags: [Shifts]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - $ref: '#/components/parameters/ShiftId'
 */
router.put('/:id', verifyToken, isAdmin, shiftController.updateShift);

/**
 * @swagger
 * /api/shifts/{id}:
 *   delete:
 *     summary: Delete a shift template (Admin only)
 *     tags: [Shifts]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - $ref: '#/components/parameters/ShiftId'
 */
router.delete('/:id', verifyToken, isAdmin, shiftController.deleteShift);

export default router;
