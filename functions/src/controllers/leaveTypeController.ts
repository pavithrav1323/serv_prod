import { Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import * as admin from 'firebase-admin';
import { db } from '../config/firebase';

const COLL = 'leave_types';

/**
 * POST /api/leave-types
 * Body: { type, fromDate, toDate, days }
 * Admin only
 */
export const createLeaveType = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { userId, role } = ((req as any).user ?? {}) as { userId?: string; role?: string };
    if (role !== 'admin') {
      return res.status(200).json({ message: 'Access restricted to administrators' });
    }

    let { type, fromDate, toDate, days } = (req.body ?? {}) as {
      type?: string;
      fromDate?: string;
      toDate?: string;
      days?: number | string;
    };

    type = String(type ?? '').trim();

    // >>> SHIFT REMOVED: only require type/fromDate/toDate/days
    if (!type || !fromDate || !toDate || days == null) {
      return res.status(200).json({ message: 'Please fill in all required fields' });
    }

    const s = new Date(fromDate);
    const e = new Date(toDate);
    const allowedDays = Number(days);

    if (Number.isNaN(s.getTime()) || Number.isNaN(e.getTime()) || e < s) {
      return res.status(200).json({ message: 'Please enter valid dates' });
    }
    if (!Number.isFinite(allowedDays) || allowedDays <= 0) {
      return res.status(200).json({ message: 'Number of days must be greater than zero' });
    }

    const id = uuidv4();
    const payload = {
      id,
      type,
      // >>> SHIFT REMOVED: no shift field in payload
      fromDate: admin.firestore.Timestamp.fromDate(s),
      toDate: admin.firestore.Timestamp.fromDate(e),
      allowedDays,
      active: true,
      createdBy: userId ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection(COLL).doc(id).set(payload);
    return res.status(201).json(payload);
  } catch (err: any) {
    console.error('[leave-types:create] error', err);
    return res.status(200).json({ message: 'An error occurred while processing your request' });
  }
};

/**
 * GET /api/leave-types
 * (shift filter removed)
 */
export const listLeaveTypes = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    // >>> SHIFT REMOVED: always return active leave types, no query param needed
    const snaps = await db.collection(COLL).where('active', '==', true).get();
    const out = snaps.docs.map((d) => d.data());
    return res.status(200).json(out);
  } catch (err: any) {
    console.error('[leave-types:list] error', err);
    return res.status(200).json({ message: 'Unable to load leave types' });
  }
};

/**
 * DELETE /api/leave-types/:id
 * Admin only
 */
export const deleteLeaveType = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { role } = ((req as any).user ?? {}) as { role?: string };
    if (role !== 'admin') {
      return res.status(200).json({ message: 'Access restricted to administrators' });
    }

    const { id } = req.params;
    if (!id) {
      return res.status(200).json({ message: 'Leave type not found' });
    }

    // First check if the document exists
    const doc = await db.collection(COLL).doc(id).get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Leave type not found' });
    }

    // Soft delete by setting active to false
    await db.collection(COLL).doc(id).update({
      active: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return res.status(200).json({
      status: 'success',
      message: 'Leave type deleted successfully'
    });
  } catch (err: any) {
    console.error('[leave-types:delete] error', err);
    return res.status(500).json({
      error: err?.message || 'Failed to delete leave type'
    });
  }
};
