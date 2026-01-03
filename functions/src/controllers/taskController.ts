// src/controllers/taskController.ts
import { Request, Response } from 'express';
import { db } from '../config/firebase';

// Re-export the user type for consistency with auth middleware
export type AuthUser = {
  userId: string;
  email: string;
  role: string;
  empid?: string | null;
  uid?: string; // backward compatibility
};

type Audience = 'all' | 'employee';

interface TaskDoc {
  id: string;
  title: string;
  description: string;
  audience: Audience;
  assignedTo: string | null; // empid when audience='employee'
  dueDate: string | null;    // yyyy-MM-dd or ISO string
  kind: string;              // "Task" | "DailyUpdate" | etc.
  file: null;                // always null now
  status: 'assigned';
  createdBy: string;
  createdAt: string; // ISO
  updatedAt: string; // ISO
}

function toIsoOrNull(v?: string | null): string | null {
  if (!v) return null;
  const s = String(v).trim();
  if (!s) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  const d = new Date(s);
  return isNaN(d.getTime()) ? null : d.toISOString();
}

function makeTaskDoc({
  id,
  title,
  description,
  dueDate,
  kind,
  user,
  audience,
  assignedTo,
}: {
  id: string;
  title?: string;
  description?: string;
  dueDate?: string | null;
  kind?: string;
  user?: AuthUser;
  audience: Audience;
  assignedTo?: string | null;
}): TaskDoc {
  const nowIso = new Date().toISOString();
  return {
    id,
    title: (title ?? 'Task').trim() || 'Task',
    description: (description ?? '').trim(),
    audience,
    assignedTo: audience === 'employee' ? (assignedTo || '').trim() : null,
    dueDate: toIsoOrNull(dueDate),
    kind: (kind ?? 'Task').trim() || 'Task',
    file: null,
    status: 'assigned',
    createdBy: user?.userId || user?.uid || 'admin',
    createdAt: nowIso,
    updatedAt: nowIso,
  };
}

/** 🔊 Admin: create a broadcast task (no file)
 *  ✅ BACKWARD-COMPAT: also supports audience='employee' + assignedTo for single-employee create
 */
export async function createBroadcastTask(req: Request, res: Response) {
  try {
    const {
      title = '',
      description = '',
      dueDate = null,
      kind = 'Task',
      audience: rawAudience,             // <-- NEW (optional)
      assignedTo: rawAssignedTo,         // <-- NEW (optional)
    } = (req.body ?? {}) as {
      title?: string;
      description?: string;
      dueDate?: string | null;
      kind?: string;
      audience?: string;
      assignedTo?: string;
    };

    if (!description || !String(description).trim()) {
      return res.status(400).json({ error: 'description is required' });
    }

    // 🟣 NEW: If audience='employee' and assignedTo present, treat as single-employee task
    const audience = (rawAudience || 'all').toString().toLowerCase().trim() as Audience;
    const assignedTo = (rawAssignedTo || '').toString().trim();

    if (audience === 'employee') {
      if (!assignedTo) {
        return res.status(400).json({ error: 'assignedTo (empid) is required when audience="employee"' });
      }
      const docRef = db.collection('tasks').doc();
      const data = makeTaskDoc({
        id: docRef.id,
        title,
        description,
        dueDate,
        kind,
        user: req.user as AuthUser | undefined,
        audience: 'employee',
        assignedTo,
      });
      await docRef.set(data);
      return res.status(201).json(data);
    }

    // Default behavior: broadcast to all
    const docRef = db.collection('tasks').doc();
    const data = makeTaskDoc({
      id: docRef.id,
      title,
      description,
      dueDate,
      kind,
      user: req.user as AuthUser | undefined,
      audience: 'all',
    });

    await docRef.set(data);
    return res.status(201).json(data);
  } catch (e: any) {
    return res
      .status(500)
      .json({ error: 'Failed to create broadcast task', details: e?.message || String(e) });
  }
}

/** 🎯 Admin: create a task for ONE employee (no file) */
export async function createSingleTask(req: Request, res: Response) {
  try {
    const {
      assignedTo = '',
      title = '',
      description = '',
      dueDate = null,
      kind = 'Task',
    } = (req.body ?? {}) as {
      assignedTo?: string;
      title?: string;
      description?: string;
      dueDate?: string | null;
      kind?: string;
    };

    if (!assignedTo || !assignedTo.trim()) {
      return res.status(400).json({ error: 'assignedTo (empid) is required' });
    }
    if (!description || !String(description).trim()) {
      return res.status(400).json({ error: 'description is required' });
    }

    const docRef = db.collection('tasks').doc();

    const data = makeTaskDoc({
      id: docRef.id,
      title,
      description,
      dueDate,
      kind,
      user: (req.user as AuthUser | undefined),
      audience: 'employee',
      assignedTo,
    });

    await docRef.set(data);
    return res.status(201).json(data);
  } catch (e: any) {
    return res
      .status(500)
      .json({ error: 'Failed to create task', details: e?.message || String(e) });
  }
}

/** ✍️ Employee self-post: create Daily Update for the logged-in user */
export async function createDailyUpdateForSelf(req: Request, res: Response) {
  try {
    const user = (req.user as AuthUser | undefined);
    const empid = (user?.empid || '').trim();

    if (!empid) {
      return res.status(400).json({ error: 'empid missing on user token' });
    }

    const {
      description = '',
      title = 'Daily Update',
      dueDate = null,
    } = (req.body ?? {}) as {
      description?: string;
      title?: string;
      dueDate?: string | null;
    };

    if (!description || !String(description).trim()) {
      return res.status(400).json({ error: 'description is required' });
    }

    const docRef = db.collection('tasks').doc();

    const data = makeTaskDoc({
      id: docRef.id,
      title,
      description,
      dueDate,
      kind: 'DailyUpdate',
      user,
      audience: 'employee',
      assignedTo: empid, // from token
    });

    await docRef.set(data);
    return res.status(201).json(data);
  } catch (e: any) {
    return res
      .status(500)
      .json({ error: 'Failed to create daily update', details: e?.message || String(e) });
  }
}

/** 📜 Admin/broadcast list (audience='all' only) */
export async function listTasks(_req: Request, res: Response) {
  try {
    const snap = await db
      .collection('tasks')
      .where('audience', '==', 'all')
      .orderBy('createdAt', 'desc')
      .get();

    return res.json(snap.docs.map((d) => d.data()));
  } catch (e: any) {
    return res.status(500).json({ error: 'Failed to fetch tasks', details: e?.message || String(e) });
  }
}

/**
 * 👤 User-merged list: broadcast + personal
 * - If empid is provided (query or token), return only tasks assigned to that empid.
 * - If empid is missing, still return ALL personal tasks (audience='employee').
 */
export async function listTasksForUser(req: Request, res: Response) {
  try {
    const authUser = (req.user as AuthUser | undefined);
    const qEmp = ((req.query.empid as string) || authUser?.empid || '').trim();

    // Broadcast query (always)
    const qBroadcast = db
      .collection('tasks')
      .where('audience', '==', 'all')
      .orderBy('createdAt', 'desc')
      .get();

    // Personal query
    let personalQuery = db
      .collection('tasks')
      .where('audience', '==', 'employee');

    // Filter by empid when provided; otherwise return all employee tasks
    if (qEmp) {
      personalQuery = personalQuery.where('assignedTo', '==', qEmp);
    }

    const qPersonal = personalQuery.orderBy('createdAt', 'desc').get();

    const [broadSnap, personalSnap] = await Promise.all([qBroadcast, qPersonal]);

    const all = [
      ...broadSnap.docs.map((d) => d.data()),
      ...personalSnap.docs.map((d) => d.data()),
    ];

    // Sort newest first
    all.sort((a: any, b: any) => {
      const ad = Date.parse(a?.createdAt || '') || 0;
      const bd = Date.parse(b?.createdAt || '') || 0;
      return bd - ad;
    });

    return res.json(all);
  } catch (e: any) {
    return res
      .status(500)
      .json({ error: 'Failed to fetch tasks for user', details: e?.message || String(e) });
  }
}

/**
 * 🧑‍💼 Employee-only list:
 * - If empid is provided (query), returns tasks for that empid.
 * - If empid is missing, returns ALL employee tasks (no broadcasts).
 */
export async function listEmployeeTasks(req: Request, res: Response) {
  try {
    const qEmp = (String(req.query.empid || '')).trim();

    let query = db.collection('tasks').where('audience', '==', 'employee');
    if (qEmp) {
      query = query.where('assignedTo', '==', qEmp);
    }

    const snap = await query.orderBy('createdAt', 'desc').get();
    const items = snap.docs.map((d) => d.data());

    items.sort((a: any, b: any) => {
      const ad = Date.parse(a?.createdAt || '') || 0;
      const bd = Date.parse(b?.createdAt || '') || 0;
      return bd - ad;
    });

    return res.json(items);
  } catch (e: any) {
    return res.status(500).json({
      error: 'Failed to fetch employee tasks',
      details: e?.message || String(e),
    });
  }
}

/** 🔎 Get a single task by id */
export async function getTask(req: Request, res: Response): Promise<Response> {
  try {
    const id = (req.params.id || '').trim();
    if (!id) return res.status(400).json({ error: 'id is required' });

    const snap = await db.collection('tasks').doc(id).get();
    if (!snap.exists) return res.status(404).json({ error: 'Not found' });

    return res.json(snap.data());
  } catch (e: any) {
    return res.status(500).json({
      error: 'Failed to fetch task',
      details: e?.message ?? String(e),
    });
  }
}
