import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

type FeedbackDoc = {
  empid: string;
  name: string;
  message: string;
  date: admin.firestore.Timestamp | Date;
  response: string;
  visibility: string[];
};

const COLL = 'feedbacks';

// Helper: safely get Firestore from app.locals (set by router factory)
const getDb = (req: Request): FirebaseFirestore.Firestore => {
  const locals = req.app?.locals as { db?: FirebaseFirestore.Firestore } | undefined;
  if (!locals?.db) {
    throw new Error('Database not initialized in app.locals');
  }
  return locals.db;
};

/**
 * POST /api/feedback
 * Headers (either):
 *  - x-user-id  (users/<id> doc will be resolved to empid/name), OR
 *  - x-empid AND x-name
 * Body:
 *  - { message: string }
 */
export const createFeedback = async (req: Request, res: Response) => {
  try {
    const db = getDb(req);

    const message = String(req.body?.message ?? '').trim();
    const headerUserId = String(req.header('x-user-id') ?? '').trim();
    const headerEmpId  = String(req.header('x-empid') ?? '').trim();
    const headerName   = String(req.header('x-name') ?? '').trim();

    if (!message) {
      return res.status(400).json({ error: 'Missing message' });
    }

    let empid = '';
    let name  = '';

    if (headerUserId) {
      // Resolve from users/<id>
      const snap = await db.collection('users').doc(headerUserId).get();
      if (!snap.exists) {
        return res.status(404).json({ error: 'User not found in users DB' });
      }
      const u = snap.data() ?? {};
      empid = String((u as any).empid ?? '');
      name  = String((u as any).name  ?? '');
    } else {
      // Fallback to direct meta
      empid = headerEmpId || String(req.body?.empid ?? '');
      name  = headerName  || String(req.body?.name  ?? '');
    }

    if (!empid || !name) {
      return res.status(400).json({
        error:
          'Missing user id and emp meta. Provide x-user-id OR x-empid/x-name (or empid/name in body).',
      });
    }

    const doc: FeedbackDoc = {
      empid,
      name,
      message,
      date: admin.firestore.Timestamp.now(),
      response: '',
      visibility: ['admin'],
    };

    const ref = await db.collection(COLL).add(doc);
    return res.status(201).json({ id: ref.id });
  } catch (err: any) {
    console.error('createFeedback error:', err);
    return res.status(500).json({ error: err?.message ?? 'Server error' });
  }
};

/**
 * GET /api/feedback
 * Returns an array of feedbacks (newest first).
 */
export const getAllFeedback = async (req: Request, res: Response) => {
  try {
    const db = getDb(req);
    const snap = await db.collection(COLL).orderBy('date', 'desc').get();

    const data = snap.docs.map((d) => {
      const x = d.data() as Partial<FeedbackDoc> & { [k: string]: any };

      // Normalize date to ISO string
      let iso = '';
      const dt = x?.date;
      if (dt && typeof (dt as any).toDate === 'function') {
        iso = (dt as admin.firestore.Timestamp).toDate().toISOString();
      } else if (dt instanceof Date) {
        iso = dt.toISOString();
      }

      return {
        id: d.id,
        empid: String(x?.empid ?? ''),
        name: String(x?.name ?? ''),
        message: String(x?.message ?? ''),
        response: String(x?.response ?? ''),
        visibility: Array.isArray(x?.visibility) ? x.visibility! : [],
        date: iso,
      };
    });

    return res.json(data);
  } catch (err: any) {
    console.error('getAllFeedback error:', err);
    return res.status(500).json({ error: err?.message ?? 'Server error' });
  }
};
