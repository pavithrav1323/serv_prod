import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const REWARDS = 'rewards';

type TS = admin.firestore.Timestamp;

interface Reward {
  id?: string;
  empid: string;
  name: string;
  department: string;
  description: string;
  adminname: string;
  date: Date | TS;
  createdAt: TS | Date;
  updatedAt: TS | Date;
}

/** Normalize various date inputs (ISO string / number / Firestore Timestamp) to JS Date. */
function normalizeDate(input: unknown): Date {
  if (!input) return new Date();
  if (typeof input === 'object' && input !== null && typeof (input as any).toDate === 'function') {
    try {
      return (input as TS).toDate();
    } catch {
      /* fallthrough */
    }
  }
  const d = new Date(input as any);
  return isNaN(d.getTime()) ? new Date() : d;
}

/** Safely read a string field; trims and returns '' if missing. */
function str(v: unknown): string {
  return (typeof v === 'string' ? v : '').trim();
}

/** Convert Firestore doc (or plain object) to response-friendly JSON (dates => ISO). */
function serialize(doc: FirebaseFirestore.DocumentSnapshot | any) {
  const data = (doc && typeof doc.data === 'function') ? doc.data() : doc || {};
  const out: any = { id: doc?.id ?? data.id, ...data };

  const toIso = (v: any) => {
    if (!v) return v;
    if (typeof v === 'object' && typeof v.toDate === 'function') return v.toDate().toISOString();
    if (v instanceof Date) return v.toISOString();
    return v;
  };

  out.date = toIso(out.date);
  out.createdAt = toIso(out.createdAt);
  out.updatedAt = toIso(out.updatedAt);

  return out;
}

// ---------------------------------------------------------------------------
// Controllers
// ---------------------------------------------------------------------------

/** POST /api/rewards */
export const createReward = async (req: Request, res: Response): Promise<Response> => {
  try {
    const body = (req.body || {}) as Partial<Reward>;
    const empid = str(body.empid);
    const name = str(body.name);
    const department = str(body.department);
    const description = str(body.description);

    // If you use auth, prefer admin name from token; else body/admin fallback
    const user = (req as any).user;
    const adminname =
      str(user?.name) ||
      str(user?.email) ||
      str((body as any).adminname) ||
      'Admin';

    const missing: string[] = [];
    if (!empid) missing.push('empid');
    if (!name) missing.push('name');
    if (!department) missing.push('department');
    if (!description) missing.push('description');
    if (!adminname) missing.push('adminname');

    if (missing.length) {
      return res.status(400).json({ error: `Missing fields: ${missing.join(', ')}` });
    }

    const now = admin.firestore.Timestamp.now();
    const reward: Reward = {
      empid,
      name,
      department,
      description,
      adminname,
      date: normalizeDate((body as any).date),
      createdAt: now,
      updatedAt: now,
    };

    const docRef = await db.collection(REWARDS).add(reward);
    const saved = await docRef.get();
    return res.status(201).json(serialize(saved));
  } catch (error: any) {
    console.error('createReward error:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
};

/**
 * GET /api/rewards
 * If ?empid= is provided, tries exact / lower / upper case variants, merges, sorts by date desc.
 * If not provided, returns all rewards ordered by date desc.
 */
export const getAllRewards = async (req: Request, res: Response): Promise<Response> => {
  try {
    const empidParam = str((req.query as any)?.empid);
    const rewards: any[] = [];

    if (empidParam) {
      const tried = new Set<string>();
      const variants = [empidParam];
      const lc = empidParam.toLowerCase();
      const uc = empidParam.toUpperCase();
      if (lc !== empidParam) variants.push(lc);
      if (uc !== empidParam && uc !== lc) variants.push(uc);

      for (const v of variants) {
        if (tried.has(v)) continue;
        tried.add(v);

        const snap = await db.collection(REWARDS).where('empid', '==', v).get();
        for (const d of snap.docs) rewards.push(serialize(d));

        // If exact value returned matches, can break early
        if (rewards.length && v === empidParam) break;
      }

      // Dedup by id
      const dedup = Object.values(
        rewards.reduce<Record<string, any>>((acc, r: any) => {
          acc[r.id] = r;
          return acc;
        }, {})
      );

      // Sort newest first using normalized date
      dedup.sort((a: any, b: any) => new Date(b.date || 0).getTime() - new Date(a.date || 0).getTime());
      return res.json(dedup);
    }

    // No filter
    const snapshot = await db.collection(REWARDS).orderBy('date', 'desc').get();
    return res.json(snapshot.docs.map((d) => serialize(d)));
  } catch (error: any) {
    console.error('getAllRewards error:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
};

/** GET /api/rewards/:id */
export const getRewardById = async (req: Request, res: Response): Promise<Response> => {
  try {
    const id = String(req.params.id);
    const doc = await db.collection(REWARDS).doc(id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Not found' });
    return res.json(serialize(doc));
  } catch (error: any) {
    console.error('getRewardById error:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
};

/** DELETE /api/rewards/:id */
export const deleteReward = async (req: Request, res: Response): Promise<Response> => {
  try {
    const id = String(req.params.id);
    await db.collection(REWARDS).doc(id).delete();
    return res.json({ message: 'Deleted successfully' });
  } catch (error: any) {
    console.error('deleteReward error:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
};

/** GET /api/rewards/mine  (requires auth; expects req.user.empid) */
export const getMyRewards = async (req: Request, res: Response): Promise<Response> => {
  try {
    const empid = str((req as any).user?.empid);
    if (!empid) return res.status(401).json({ error: 'Unauthorized: missing empid' });

    const snap = await db.collection(REWARDS).where('empid', '==', empid).get();
    const list = snap.docs.map((d) => serialize(d));
    return res.json(list);
  } catch (error: any) {
    console.error('getMyRewards error:', error);
    return res.status(500).json({ error: error.message || 'Server error' });
  }
};
