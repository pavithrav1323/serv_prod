// functions/src/routes/admin.ts
import { Router } from "express";
import { createAdmin, promoteToAdmin } from "../controllers/adminController";
import { authMiddleware as requireAuth, isAdmin as requireAdmin } from "../middlewares/authMiddleware";

const router = Router();

// secure these with admin-only token
router.post("/create", requireAuth, requireAdmin, createAdmin);
router.post("/promote", requireAuth, requireAdmin, promoteToAdmin);

export default router;
