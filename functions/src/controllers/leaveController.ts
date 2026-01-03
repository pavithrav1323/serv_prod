
import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

const db = admin.firestore();

/* ============================== Types ============================== */

type LeaveType =
  | 'Casual Leave'
  | 'Planned Leave'
  | 'Sick Leave'
  | 'Half-Day'
  | 'Overtime'
  | 'Permission Time'
  | 'Comp Off';

type LeaveStatus = 'Pending' | 'Approved' | 'Rejected' | 'Cancelled';

interface LeaveRequest {
  id?: string;
  userId: string;
  empid: string;
  name: string;
  leaveType: LeaveType;
  startDate: string; // YYYY-MM-DD (inclusive)
  endDate: string;   // YYYY-MM-DD (inclusive)
  reason: string;
  status: LeaveStatus;
  session?: 'Morning' | 'Afternoon';
  duration?: number;               // hours (OT/Permission)
  attachmentUrl?: string;
  documentUrl?: string;
  imageUrl?: string;
  selectShift?: string | null;
  workedDate?: string;             // YYYY-MM-DD (reference day actually worked for Comp Off)
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
  requestedAt?: admin.firestore.Timestamp;
  approverId?: string;
  approverNotes?: string;
}

/* ============================== Helpers ============================== */

const VALID_TYPES: LeaveType[] = [
  'Casual Leave',
  'Planned Leave',
  'Sick Leave',
  'Half-Day',
  'Overtime',
  'Permission Time',
  'Comp Off',
];

const toYMD = (v: any): string => {
  if (!v) return '';
  if (typeof v === 'string') {
    try {
      if (/^\d{4}-\d{2}-\d{2}$/.test(v)) return v;
      return new Date(v).toISOString().slice(0, 10);
    } catch {
      return '';
    }
  }
  try {
    return new Date(v).toISOString().slice(0, 10);
  } catch {
    return '';
  }
};

const clampRange = (start: string, end: string): { start: string; end: string } => {
  const s = toYMD(start);
  const e = toYMD(end);
  if (!s || !e) return { start: '', end: '' };
  if (new Date(e) < new Date(s)) return { start: '', end: '' };
  return { start: s, end: e };
};

function normalizeCreatePayload(
  currentUser: any,
  raw: any,
  empName: string
): { data?: Omit<LeaveRequest, 'id'>; error?: string } {
  let {
    leaveType,
    startDate,
    endDate,
    reason,
    session,
    duration,
    attachmentUrl,
    // legacy fields:
    type,
    fromDate,
    toDate,
    selectDate,
    selectShift,
    startTime,
    endTime,
    documentUrl,
    imageUrl,
    workedDate,
  } = raw || {};

  if (!leaveType && type) leaveType = type;
  if (!leaveType || !VALID_TYPES.includes(leaveType)) return { error: 'Invalid or missing leaveType' };
  if (!reason) return { error: 'Missing reason' };

  const nowTs = admin.firestore.Timestamp.now();
  const base: Omit<LeaveRequest, 'id'> = {
    userId: currentUser.userId,
    empid: currentUser.empid,
    name: empName,
    leaveType,
    startDate: '',
    endDate: '',
    reason: String(reason),
    status: 'Pending',
    createdAt: nowTs,
    updatedAt: nowTs,
    requestedAt: nowTs,
  };

  if (attachmentUrl) base.attachmentUrl = String(attachmentUrl);
  if (documentUrl)   base.documentUrl   = String(documentUrl);
  if (imageUrl)      base.imageUrl      = String(imageUrl);
  if (selectShift)   base.selectShift   = String(selectShift);

  // ---------------- Overtime / Permission Time ----------------
  if (leaveType === 'Overtime' || leaveType === 'Permission Time') {
    const date = toYMD(selectDate || startDate);
    if (!date) return { error: 'selectDate/startDate required for Overtime/Permission' };

    if (duration != null) {
      const d = Number(duration);
      if (!(d > 0)) return { error: 'duration must be > 0 (hours)' };
      base.duration = d;
    } else {
      if (!startTime || !endTime) return { error: 'startTime and endTime are required (or provide duration)' };
      const st = new Date(`${date}T${String(startTime).padStart(5, '0')}:00`);
      const et = new Date(`${date}T${String(endTime ).padStart(5, '0')}:00`);
      if (isNaN(st.getTime()) || isNaN(et.getTime()) || et <= st) return { error: 'Invalid startTime/endTime' };
      base.duration = (et.getTime() - st.getTime()) / 3600000;
    }

    base.startDate = date;
    base.endDate   = date;
    return { data: base };
  }

  // ---------------- Half-Day ----------------
  if (leaveType === 'Half-Day') {
    const date = toYMD(selectDate || startDate || fromDate);
    if (!date) return { error: 'selectDate/startDate/fromDate required for Half-Day' };

    const ses =
      'session' in (raw || {}) && session
        ? session
        : (String(selectShift || '').toLowerCase().includes('morning')
            ? 'Morning'
            : (String(selectShift || '').toLowerCase().includes('afternoon') ? 'Afternoon' : undefined));
    if (!ses) return { error: 'session is required for Half-Day (Morning/Afternoon)' };

    base.startDate = date;
    base.endDate   = date;
    base.session   = ses as 'Morning' | 'Afternoon';
    return { data: base };
  }

  // ---------------- Comp Off (single day on compensate date) ----------------
  if (leaveType === 'Comp Off') {
    const worked = toYMD(workedDate || startDate || fromDate); // past day worked
    // compensate/off day: allow selectDate, endDate, toDate, or explicit startDate
    const comp   = toYMD(endDate || toDate || selectDate || startDate);
    if (!worked) return { error: 'workedDate is required for Comp Off' };
    if (!comp)   return { error: 'compensate date is required for Comp Off' };

    base.startDate = comp;
    base.endDate   = comp; // single-day leave
    base.workedDate = worked;
    return { data: base };
  }

  // ---------------- Multi-day (Casual/Planned/Sick) ----------------
  const s = toYMD(startDate || fromDate);
  const e = toYMD(endDate   || toDate);
  const { start, end } = clampRange(s, e);
  if (!start || !end) return { error: 'Invalid startDate/endDate' };

  base.startDate = start;
  base.endDate   = end;
  return { data: base };
}

/**
 * Map UI/API `type` query to a Firestore `leaveType` value.
 * Recognizes both your UI aliases and canonical names.
 */
function mapTypeQueryToLeaveType(q?: string): LeaveType | null {
  if (!q) return null;
  const t = String(q).trim().toLowerCase();

  if (t === 'leave:overtime' || t === 'overtime' || t === 'over time') {
    return 'Overtime';
  }
  if (t === 'leave:permission' || t === 'permission' || t === 'permission time') {
    return 'Permission Time';
  }
  if (t === 'leave:halfday' || t === 'half day' || t === 'half-day' || t === 'halfday') {
    return 'Half-Day';
  }
  if (t === 'leave:compoff' || t === 'comp off' || t === 'comp-off' || t === 'compoff') {
    return 'Comp Off';
  }
  // 'leave:any' or anything else → no specific filter
  return null;
}

/* ============================== Controllers ============================== */

// CREATE — overlap check rewritten to avoid composite index
export const createLeaveRequest = async (req: Request, res: Response): Promise<Response> => {
  try {
    const currentUser = (req as any).user;

    // Resolve display name
    let empName = '';
    const empSnap = await db.collection('employees').where('empid', '==', currentUser.empid).limit(1).get();
    if (!empSnap.empty) {
      const e = empSnap.docs[0].data() as any;
      empName = [e.firstName, e.lastName].filter(Boolean).join(' ') || e.name || '';
    }
    if (!empName) {
      const usr = await db.collection('users').doc(currentUser.userId).get();
      if (usr.exists) {
        const u = usr.data() as any;
        empName = u.name || `${u.firstName ?? ''} ${u.lastName ?? ''}`.trim();
      }
    }

    const norm = normalizeCreatePayload(currentUser, req.body, empName || 'Employee');
    if (norm.error) return res.status(400).json({ error: norm.error });
    const payload = norm.data!;

    // ---- Index-free overlap check (query by userId only; filter in memory) ----
    if (payload.leaveType !== 'Overtime' && payload.leaveType !== 'Permission Time') {
      const existing = await db.collection('leaves')
        .where('userId', '==', currentUser.userId)
        .get();

      const overlaps = existing.docs.some((d) => {
        const v = d.data() as any;
        if (!['Pending', 'Approved'].includes(String(v.status))) return false;
        const s = String(v.startDate || '');
        const e = String(v.endDate   || '');
        return s <= payload.endDate && e >= payload.startDate;
      });

      if (overlaps) {
        const msg = payload.leaveType === 'Comp Off'
          ? 'You have already applied for leave/comp-off on the selected date.'
          : 'You already have a leave request for the selected date range.';

        // Simple message without technical details
        return res.status(200).json({ message: msg });
      }
    }
    // --------------------------------------------------------------------------

    const ref  = await db.collection('leaves').add(payload);
    const snap = await ref.get();
    return res.status(201).json({ id: ref.id, ...snap.data() });
  } catch (error) {
    console.error('Error creating leave request:', error);
    return res.status(500).json({ error: 'Failed to create leave request' });
  }
};

// ADMIN: list with optional filters + naive pagination
export const getAllLeaveRequests = async (req: Request, res: Response): Promise<Response> => {
  try {
    const currentUser = (req as any).user;
    const { status, userId, startDate, endDate, page = '1', limit = '10', type } = req.query;

    if (currentUser.role !== 'admin' && userId !== currentUser.userId) {
      return res.status(403).json({ error: 'Unauthorized to view these leave requests' });
    }

    let q: FirebaseFirestore.Query<FirebaseFirestore.DocumentData> = db.collection('leaves');

    if (status) q = q.where('status', '==', String(status));
    if (userId) q = q.where('userId', '==', String(userId));
    if (startDate && endDate) {
      q = q
        .where('startDate', '<=', String(endDate))
        .where('endDate', '>=', String(startDate));
    }

    // Filter by leave type if specified
    const leaveTypeFilter = mapTypeQueryToLeaveType(type as string | undefined);
    if (leaveTypeFilter) {
      q = q.where('leaveType', '==', leaveTypeFilter);
    }

    // Get total count for pagination
    const all = await q.get();
    const total = all.size;

    // Apply pagination
    const pageNum = Math.max(parseInt(String(page), 10) || 1, 1);
    const limitNum = Math.min(Math.max(parseInt(String(limit), 10) || 10, 1), 100);
    const offset = Math.max(0, (pageNum - 1) * limitNum);

    const pageSnap = await q.offset(offset).limit(limitNum).get();

    return res.status(200).json({
      data: pageSnap.docs.map(d => ({ id: d.id, ...d.data() })),
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum)
      }
    });
  } catch (error) {
    console.error('Error fetching leave requests:', error);
    return res.status(500).json({
      error: 'Failed to fetch leave requests',
      details: error instanceof Error ? error.message : 'Unknown error',
    });
  }
};
export const getPendingLeaves = async (req: Request, res: Response): Promise<Response> => {
  try {
    const t = req.query.type ? String(req.query.type) : undefined;
    let q: FirebaseFirestore.Query = db.collection('leaves').where('status', '==', 'Pending');

    if (t) {
      q = q.where('leaveType', '==', t);
    }

    const snapshot = await q.orderBy('startDate', 'asc').get();
    const pendingLeaves = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    return res.status(200).json(pendingLeaves);
  } catch (error) {
    console.error('Error fetching pending leaves:', error);
    return res.status(500).json({
      error: 'Failed to fetch pending leaves',
      details: error instanceof Error ? error.message : 'Unknown error',
    });
  }
};

export const getLeaveBalance = async (req: Request, res: Response): Promise<Response> => {
  try {
    const currentUser = (req as any).user;
    const empSnap = await db.collection('employees').where('empid', '==', currentUser.empid).limit(1).get();
    
    if (empSnap.empty) {
      return res.status(404).json({ error: 'Employee not found' });
    }
    
    const employee = empSnap.docs[0].data();
    
    return res.status(200).json({
      casualLeave: employee.casualLeave || 0,
      plannedLeave: employee.plannedLeave || 0,
      sickLeave: employee.sickLeave || 0,
    });
  } catch (error) {
    console.error('Error fetching leave balance:', error);
    return res.status(500).json({
      error: 'Failed to fetch leave balance',
      details: error instanceof Error ? error.message : 'Unknown error',
    });
  }
};

export function getLeaveRequestById(id: string) {
  return db.collection('leaves').doc(id).get();
}
export const getLeaveTypes = async (req: Request, res: Response): Promise<Response> => {
  try {
    const snapshot = await db.collection('leaveTypes').orderBy('name').get();
    const leaveTypes = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    return res.status(200).json(leaveTypes);
  } catch (error) {
    console.error('Error fetching leave types:', error);
    return res.status(500).json({
      error: 'Failed to fetch leave types',
      details: error instanceof Error ? error.message : 'Unknown error',
    });
  }
};

export const addLeaveType = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { name, description = '', defaultDays = 0 } = req.body;
    
    if (!name) {
      return res.status(400).json({ error: 'Leave type name is required' });
    }

    const docRef = await db.collection('leaveTypes').add({
      name,
      description,
      defaultDays: Number(defaultDays) || 0,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return res.status(201).json({
      id: docRef.id,
      name,
      description,
      defaultDays: Number(defaultDays) || 0,
      isActive: true
    });
  } catch (error) {
    console.error('Error adding leave type:', error);
    return res.status(500).json({
      error: 'Failed to add leave type',
      details: error instanceof Error ? error.message : 'Unknown error',
    });
  }
};

export const deleteLeaveType = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { id } = req.body;
    
    if (!id) {
      return res.status(400).json({ error: 'Leave type ID is required' });
    }

    // Check if any leaves are using this type
    const leavesSnapshot = await db.collection('leaves')
      .where('leaveTypeId', '==', id)
      .limit(1)
      .get();

    if (!leavesSnapshot.empty) {
      return res.status(400).json({
        error: 'Cannot delete leave type as it is being used by existing leave requests'
      });
    }

    await db.collection('leaveTypes').doc(id).delete();
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error deleting leave type:', error);
    return res.status(500).json({
      error: 'Failed to delete leave type',
      details: error instanceof Error ? error.message : 'Unknown error',
    });
  }
};

export const updateLeaveStatus = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { id } = req.params;
    const { status, notes } = req.body;
    const currentUser = (req as any).user;

    if (!['Approved', 'Rejected', 'Cancelled'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const leaveRef = db.collection('leaves').doc(id);
    const leaveDoc = await leaveRef.get();

    if (!leaveDoc.exists) {
      return res.status(404).json({ error: 'Leave request not found' });
    }

    const updates: any = {
      status,
      approverId: currentUser.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(notes && { approverNotes: notes })
    };

    await leaveRef.update(updates);
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error updating leave status:', error);
    return res.status(500).json({
      error: 'Failed to update leave status',
      details: error instanceof Error ? error.message : 'Unknown error',
    });
  }
};

export const cancelLeaveRequest = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { id } = req.params;
    const currentUser = (req as any).user;
    const { reason } = req.body;

    const leaveRef = db.collection('leaves').doc(id);
    const leaveDoc = await leaveRef.get();

    if (!leaveDoc.exists) {
      return res.status(404).json({ error: 'Leave request not found' });
    }

    const leaveData = leaveDoc.data();
    
    // Only allow cancellation if user is admin or the requester
    if (currentUser.role !== 'admin' && leaveData?.userId !== currentUser.uid) {
      return res.status(403).json({ error: 'Not authorized to cancel this leave' });
    }

    // Only pending leaves can be cancelled
    if (leaveData?.status !== 'Pending') {
      return res.status(400).json({ error: 'Only pending leave requests can be cancelled' });
    }

    await leaveRef.update({
      status: 'Cancelled',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy: currentUser.uid,
      cancelReason: reason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error cancelling leave request:', error);
    return res.status(500).json({
      error: 'Failed to cancel leave request',
      details: error instanceof Error ? error.message : 'Unknown error',
    });
  }
};

export const deleteLeave = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { id } = req.params;
    
    const leaveDoc = await db.collection('leaves').doc(id).get();
    if (!leaveDoc.exists) {
      return res.status(404).json({ error: 'Leave request not found' });
    }

    await db.collection('leaves').doc(id).delete();
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error deleting leave request:', error);
    return res.status(500).json({
      error: 'Failed to delete leave request',
      details: error instanceof Error ? error.message : 'Unknown error',
    });
  }
};
