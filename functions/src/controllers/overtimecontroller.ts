import { Request, Response } from "express";
import * as admin from "firebase-admin";

// Firestore reference
const db = admin.firestore();

/**
 * GET /api/overtime?empid=EMP001&date=2025-10-28
 * Returns overtime hours for an employee on the given date
 */
export const getOvertimeHours = async (req: Request, res: Response): Promise<void> => {
  try {
    const empid = req.query.empid?.toString().trim();
    const date = req.query.date?.toString().trim();

    if (!empid || !date) {
      res.status(400).json({ ok: false, error: "Missing empid or date" });
      return;
    }

    const snapshot = await db
      .collection("leaves")
      .where("empid", "==", empid)
      .where("leaveType", "==", "Overtime")
      .where("startDate", "==", date)
      .where("endDate", "==", date)
      .limit(1)
      .get();

    if (snapshot.empty) {
      res.json({ ok: true, overtimeHours: 0 });
      return;
    }

    const data = snapshot.docs[0].data();
    const duration = Number(data.duration ?? 0);

    res.json({ ok: true, overtimeHours: duration });
  } catch (error: any) {
    console.error("Error fetching overtime:", error);
    res.status(500).json({ ok: false, error: error.message || "Internal Server Error" });
  }
};
