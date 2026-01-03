// src/routes/task.ts
import { Router } from 'express';
import { verifyToken, isAdmin } from '../middlewares/authMiddleware';
import {
  createBroadcastTask,
  createSingleTask,
  listTasks,
  getTask,
  listTasksForUser,
  createDailyUpdateForSelf,
  listEmployeeTasks, // NEW
} from '../controllers/taskController';

const router = Router();

/** Admin: create a broadcast task for all employees (JSON only, no files) */
router.post('/broadcast', verifyToken, isAdmin, createBroadcastTask);

/** Admin: create a task for exactly one employee (JSON only, no files) */
router.post('/assign', verifyToken, isAdmin, createSingleTask);

/** Employee self-post: create a Daily Update for the logged-in user (JSON only) */
router.post('/daily-update', verifyToken, createDailyUpdateForSelf);

/** User view: merged list for the current employee. */
router.get('/user', verifyToken, listTasksForUser);

/** Employee-only list (optionally filter by empid). */
router.get('/employee', verifyToken, listEmployeeTasks);

/** Admin/broadcast list (kept for compatibility). */
router.get('/', verifyToken, listTasks);

/** Single task by id. */
router.get('/:id', verifyToken, getTask);

export default router;
