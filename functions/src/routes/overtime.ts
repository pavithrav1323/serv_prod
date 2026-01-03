import { Router } from "express";
import { getOvertimeHours } from "../controllers/overtimecontroller";

const router = Router();

/**
 * Route: /api/overtime
 * Example: GET /api/overtime?empid=EMP001&date=2025-10-28
 */
router.get("/", getOvertimeHours);

export default router;
