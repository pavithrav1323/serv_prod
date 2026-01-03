import { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import * as bcrypt from 'bcryptjs';

const db = admin.firestore();
const EMPLOYEES = 'employees';

interface Employee {
  id?: string;
  empid: string;
  name: string;
  email: string;
  phone?: string;
  location?: string;
  dept?: string;
  designation?: string;
  shiftGroup?: string | null;
  role?: string; // optional role metadata stored with employee record
  status: 'active' | 'inactive';
  // stored only if provided at creation/update (hashed)
  password?: string;
  // denormalized helpers
  emailLower?: string;
  searchKeywords?: string[];

  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
  createdBy?: string;
  updatedBy?: string;
}

const stripPassword = (data: FirebaseFirestore.DocumentData) => {
  const { password, ...rest } = data || {};
  return rest;
};

const buildSearchKeywords = (e: {
  empid?: string;
  name?: string;
  email?: string;
  phone?: string;
  dept?: string;
  designation?: string;
}) => {
  const bag = new Set<string>();
  const push = (v?: string) => {
    if (!v) return;
    const s = String(v).toLowerCase();
    bag.add(s);
    // split on space and add tokens
    s.split(/[^\w]+/).forEach(t => t && bag.add(t));
  };
  push(e.empid);
  push(e.name);
  push(e.email);
  push(e.phone);
  push(e.dept);
  push(e.designation);
  return Array.from(bag);
};

// Create a new employee (Admin only)
export const createEmployee = async (req: Request, res: Response): Promise<Response> => {
  try {
    const {
      empid,
      name,
      email,
      phone,
      location,
      dept,
      designation,
      shiftGroup,
      role,
      status = 'active',
      password, // optional – if provided, will be hashed and stored
    } = req.body as Partial<Employee> & { password?: string };

    if (!empid || !email || !name) {
      return res.status(400).json({ error: 'Missing required fields: empid, name, email' });
    }

    // Uniqueness checks
    const byEmp = await db.collection(EMPLOYEES).where('empid', '==', empid).limit(1).get();
    if (!byEmp.empty) {
      return res.status(409).json({ error: 'Employee with this ID already exists' });
    }

    const emailLower = String(email).toLowerCase();
    const byEmail = await db.collection(EMPLOYEES).where('emailLower', '==', emailLower).limit(1).get();
    if (!byEmail.empty) {
      return res.status(409).json({ error: 'Employee with this email already exists' });
    }

    const currentUserId = (req as any).user?.userId;
    if (!currentUserId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const now = admin.firestore.Timestamp.now();
    const employeeData: Employee = {
      empid,
      name,
      email: emailLower,
      emailLower,
      phone,
      location,
      dept,
      designation,
      shiftGroup: shiftGroup ?? null,
      role,
      status: status as 'active' | 'inactive',
      createdAt: now,
      updatedAt: now,
      createdBy: currentUserId,
      updatedBy: currentUserId,
      searchKeywords: buildSearchKeywords({ empid, name, email, phone, dept, designation }),
    };

    if (password) {
      employeeData.password = await bcrypt.hash(String(password), 10);
    }

    const ref = await db.collection(EMPLOYEES).add(employeeData);
    const created = await ref.get();

    return res.status(201).json({ id: ref.id, ...(stripPassword(created.data() || {})) });
  } catch (error) {
    console.error('Error creating employee:', error);
    return res.status(500).json({ error: 'Failed to create employee' });
  }
};

// Get all employees (Admin; supports filters & pagination)
export const getEmployees = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { status, search, page = '1', limit = '10000' } = req.query;
    const pageNum = Math.max(parseInt(page as string, 10) || 1, 1);
    const limitNum = Math.min(Math.max(parseInt(limit as string, 10) || 10, 1), 100);
    const offset = (pageNum - 1) * limitNum;

    let q: FirebaseFirestore.Query<FirebaseFirestore.DocumentData> = db.collection(EMPLOYEES);

    if (status === 'active' || status === 'inactive') {
      q = q.where('status', '==', status);
    }

    if (search && String(search).trim()) {
      q = q.where('searchKeywords', 'array-contains', String(search).toLowerCase().trim());
    }

    // total count (inefficient but simple; for large sets, switch to cursors)
    const totalSnap = await q.get();
    const total = totalSnap.size;

    const listSnap = await q.orderBy('createdAt', 'desc').offset(offset).limit(limitNum).get();
    const data = listSnap.docs.map(d => ({ id: d.id, ...(stripPassword(d.data())) }));

    return res.status(200).json({
      data,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('Error fetching employees:', error);
    return res.status(500).json({ error: 'Failed to fetch employees' });
  }
};

// Get employee by document ID
export const getEmployeeById = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { id } = req.params;
    const doc = await db.collection(EMPLOYEES).doc(id).get();

    if (!doc.exists) {
      return res.status(404).json({ error: 'Employee not found' });
    }

    return res.status(200).json({ id: doc.id, ...(stripPassword(doc.data() || {})) });
  } catch (error) {
    console.error('Error fetching employee:', error);
    return res.status(500).json({ error: 'Failed to fetch employee' });
  }
};

// Update employee (Admin only)
export const updateEmployee = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { id } = req.params;
    const updates = { ...(req.body || {}) } as Partial<Employee> & { password?: string };

    const currentUserId = (req as any).user?.userId;
    if (!currentUserId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const ref = db.collection(EMPLOYEES).doc(id);
    const doc = await ref.get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'Employee not found' });
    }

    if (updates.email) {
      updates.emailLower = String(updates.email).toLowerCase();
    }

    if (updates.password) {
      updates.password = await bcrypt.hash(String(updates.password), 10);
    }

    // refresh search keywords if core fields change
    const recomputeKeywords =
      updates.empid || updates.name || updates.email || updates.phone || updates.dept || updates.designation;

    const patch: Partial<Employee> = {
      ...updates,
      ...(recomputeKeywords
        ? {
            searchKeywords: buildSearchKeywords({
              empid: updates.empid ?? doc.get('empid'),
              name: updates.name ?? doc.get('name'),
              email: (updates.email ?? doc.get('email')) as string,
              phone: updates.phone ?? doc.get('phone'),
              dept: updates.dept ?? doc.get('dept'),
              designation: updates.designation ?? doc.get('designation'),
            }),
          }
        : {}),
      updatedAt: admin.firestore.Timestamp.now(),
      updatedBy: currentUserId,
    };

    await ref.update(patch);

    const updated = await ref.get();
    return res.status(200).json({ id: updated.id, ...(stripPassword(updated.data() || {})) });
  } catch (error) {
    console.error('Error updating employee:', error);
    return res.status(500).json({ error: 'Failed to update employee' });
  }
};

// Delete employee (Admin only) — hard delete; switch to soft delete if needed
export const deleteEmployee = async (req: Request, res: Response): Promise<Response> => {
  try {
    const { id } = req.params;
    await db.collection(EMPLOYEES).doc(id).delete();
    return res.status(200).json({ message: 'Employee deleted successfully' });
  } catch (error) {
    console.error('Error deleting employee:', error);
    return res.status(500).json({ error: 'Failed to delete employee' });
  }
};