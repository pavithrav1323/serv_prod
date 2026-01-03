import { Router } from 'express';
import * as ctrl from '../controllers/rewardController';
import { authMiddleware, roleMiddleware } from '../middlewares/authMiddleware';

const router = Router();

/**
 * @swagger
 * tags:
 *   - name: Rewards
 *     description: Manage employee rewards (admin & user)
 *
 * components:
 *   schemas:
 *     Reward:
 *       type: object
 *       required:
 *         - empid
 *         - name
 *         - department
 *         - description
 *         - adminname
 *         - date
 *       properties:
 *         id: { type: string }
 *         empid: { type: string, description: Employee ID (recipient) }
 *         name: { type: string, description: Employee name }
 *         department: { type: string, description: Department }
 *         description: { type: string, description: Reason/context }
 *         adminname: { type: string, description: Admin who granted reward }
 *         date: { type: string, format: date-time, description: Reward date }
 *         createdAt: { type: string, format: date-time }
 *         updatedAt: { type: string, format: date-time }
 */

// Inject auth where needed
router.post('/', authMiddleware, roleMiddleware(['admin']), ctrl.createReward);

router.get('/', ctrl.getAllRewards);

router.get('/mine', authMiddleware, ctrl.getMyRewards);

router.get('/:id', ctrl.getRewardById);

router.delete('/:id', authMiddleware, roleMiddleware(['admin']), ctrl.deleteReward);

export default router;
