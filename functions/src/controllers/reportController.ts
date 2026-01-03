// controllers/reportController.ts
import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const REPORTS = 'reports';

type TS = admin.firestore.Timestamp;

interface ReportSchedule {
  id?: string;
  name: string;
  reportType: 'Check-In' | 'Check-Out' | 'Present' | 'Absent' | 'Late Check-In';
  templateId: string;
  recipient: string;
  scheduleTime: string; // "HH:mm" or cron
  createdAt?: TS;
}

/** Create a new schedule */
export const createSchedule = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { name, reportType, templateId, recipient, scheduleTime } =
      req.body as Partial<ReportSchedule>;

    if (!name || !reportType || !templateId || !recipient || !scheduleTime) {
      return res.status(400).json({ message: 'All fields are required.' });
    }

    const docRef = await db.collection(REPORTS).add({
      name,
      reportType,
      templateId,
      recipient,
      scheduleTime,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(201).json({ id: docRef.id, message: 'Schedule created.' });
  } catch (err) {
    console.error('createSchedule error:', err);
    return res.status(500).json({ message: 'Server error.' });
  }
};

/** List all schedules */
export const listSchedules = async (_req: Request, res: Response): Promise<Response> => {
  try {
    const snap = await db.collection(REPORTS).orderBy('createdAt', 'desc').get();

    const data = snap.docs.map((d) => {
      const raw = d.data() as any;
      const createdAtIso =
        raw?.createdAt && typeof raw.createdAt.toDate === 'function'
          ? raw.createdAt.toDate().toISOString()
          : new Date().toISOString();

      return { id: d.id, ...raw, createdAt: createdAtIso };
    });

    return res.status(200).json(data);
  } catch (err) {
    console.error('listSchedules error:', err);
    return res.status(500).json({ message: 'Server error.' });
  }
};

/** Delete a schedule */
export const deleteSchedule = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { id } = req.params;
    await db.collection(REPORTS).doc(id).delete();
    return res.status(200).json({ message: 'Schedule deleted.' });
  } catch (err) {
    console.error('deleteSchedule error:', err);
    return res.status(500).json({ message: 'Server error.' });
  }
};

/** Run a schedule immediately (manual trigger) */
export const runNow = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { id } = req.params;
    const doc = await db.collection(REPORTS).doc(id).get();
    if (!doc.exists) return res.status(404).json({ message: 'Not found.' });

    // TODO: integrate with your report service if/when needed.
    // await reportService.runReport(doc.data());

    return res.status(200).json({ message: 'Report run manually.' });
  } catch (err) {
    console.error('runNow error:', err);
    return res.status(500).json({ message: 'Server error.' });
  }
};
