// // functions/src/routes/reasons.ts
// import { Router } from "express";
// import {
//   listTypes,
//   createType,
//   deleteType,
//   listReasons,
//   createReason,
//   deleteReason,
// } from "../controllers/reasonMasterController";

// // If you have auth middleware, import and use it:
// // import { verifyToken } from "../middlewares/auth";

// const router = Router();

// // Helper function to wrap async route handlers with error handling
// const wrap = (fn: any) => (req: any, res: any, next: any) =>
//   Promise.resolve(fn(req, res, next)).catch(next);

// // ---------- Health check (optional) ----------
// router.get("/__health", (_req, res) => res.json({ ok: true, at: new Date().toISOString() }));

// /* ================== Reason Types ================== */
// router.get("/types", /* verifyToken, */ wrap(listTypes));
// router.post("/types", /* verifyToken, */ wrap(createType));
// router.delete("/types/:id", /* verifyToken, */ wrap(deleteType));

// /* ==================== Reasons ===================== */
// router.get("/", /* verifyToken, */ wrap(listReasons));
// router.post("/", /* verifyToken, */ wrap(createReason));
// router.delete("/:id", /* verifyToken, */ wrap(deleteReason));

// export default router;
import { Router } from "express";
import {
  listTypes,
  createType,
  deleteType,
  listReasons,
  createReason,
  deleteReason,
} from "../controllers/reasonMasterController";

// If you have auth middleware, import and use it:
// import { verifyToken } from "../middlewares/auth";

const router = Router();

// Helper function to wrap async route handlers with error handling
const wrap = (fn: any) => (req: any, res: any, next: any) =>
  Promise.resolve(fn(req, res, next)).catch(next);

// ---------- Health check (optional) ----------
router.get("/__health", (_req, res) => res.json({ ok: true, at: new Date().toISOString() }));

/* ================== Reason Types ================== */
router.get("/types", /* verifyToken, */ wrap(listTypes));
router.post("/types", /* verifyToken, */ wrap(createType));
router.delete("/types/:id", /* verifyToken, */ wrap(deleteType));

/* ==================== Reasons ===================== */
router.get("/", /* verifyToken, */ wrap(listReasons));
router.post("/", /* verifyToken, */ wrap(createReason));
router.delete("/:id", /* verifyToken, */ wrap(deleteReason));

export default router;
