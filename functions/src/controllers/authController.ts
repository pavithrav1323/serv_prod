import { Request, Response } from 'express';
import * as bcrypt from 'bcryptjs';
import * as jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { rotatePassword } from './rotatePassword';

// ── Firebase Admin (explicit, single init) ───────────────────────────────────
import {
  getApps,
  initializeApp,
  App,
  cert,
  applicationDefault,
} from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import {
  getFirestore,
  type DocumentSnapshot,
} from 'firebase-admin/firestore';

// Choose credential: prefer service account JSON via env, else ADC.
const SERVICE_ACCOUNT_JSON = process.env.GOOGLE_SERVICE_ACCOUNT_JSON || '';
const PROJECT_ID = process.env.APP_FIREBASE_PROJECT_ID || 'servappbackend';

const APP_NAME = 'serv-core';
const existingApp = getApps().find((a) => a.name === APP_NAME);

const adminApp: App =
  existingApp ??
  initializeApp(
    {
      credential: SERVICE_ACCOUNT_JSON
        ? cert(JSON.parse(SERVICE_ACCOUNT_JSON))
        : applicationDefault(),
      projectId: PROJECT_ID,
    },
    APP_NAME
  );

console.log(
  '[ADMIN PROJECT]',
  PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT
);

const auth = getAuth(adminApp);
const db = getFirestore(adminApp);

console.log('[ADMIN PROJECT]', adminApp.options.projectId);

// ── Config ───────────────────────────────────────────────────────────────────
const JWT_SECRET = process.env.JWT_SECRET || 'your-default-jwt-secret';
const JWT_EXPIRES = process.env.JWT_EXPIRES_IN || '24h';

const USERS_COL = 'users';
const EMPS_COL = 'employees';

// Optional: where the Firebase hosted reset flow should land after completion
const RESET_CONTINUE_URL =
  process.env.RESET_CONTINUE_URL || 'https://servappbackend.web.app/reset-done';

// *** Web API key used only for server-side Firebase fallback ***
const FIREBASE_WEB_API_KEY = (process.env.APP_FIREBASE_WEB_API_KEY || '').trim();
if (!/^AIza[0-9A-Za-z_\-]{10,}$/.test(FIREBASE_WEB_API_KEY)) {
  console.error(
    'APP_FIREBASE_WEB_API_KEY looks invalid or missing (pattern check failed).'
  );
}
console.log('[env] WEB_API_KEY prefix:', FIREBASE_WEB_API_KEY.slice(0, 5));

// ── Optional mailer ──────────────────────────────────────────────────────────
let nodemailer: any = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  nodemailer = require('nodemailer');
} catch {
  /* optional */
}

function makeTransport() {
  if (!nodemailer) return null;
  if (
    !process.env.SMTP_HOST ||
    !process.env.SMTP_USER ||
    !process.env.SMTP_PASS
  )
    return null;
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: false,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
}
const mailer = makeTransport();

// ── Helpers ──────────────────────────────────────────────────────────────────
const okRoles = new Set(['employee', 'admin']);
const normEmail = (e = '') => String(e).trim().toLowerCase();

interface JwtPayload {
  userId: string;
  email: string;
  role: string;
  empid?: string | null;
  [key: string]: any;
}

const issueToken = (payload: JwtPayload): string =>
  jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES } as jwt.SignOptions);

const sanitizeUser = (id: string, data: any) => {
  const { password, passwordHash, hashedPassword, ...rest } = data || {};
  return { id, ...rest };
};

const isBcryptHash = (s = '') => /^\$2[aby]\$/.test(String(s));

/** Pick emp id independent of key style in stored docs */
const pickEmpId = (obj: any): string | null => {
  const v = obj?.empid ?? obj?.empId ?? obj?.employeeId ?? null;
  return v ? String(v).trim() : null;
};

async function getByEmail(colName: string, emailLower: string) {
  // preferred: emailLower
  let snap = await db
    .collection(colName)
    .where('emailLower', '==', emailLower)
    .limit(1)
    .get();
  if (!snap.empty) return snap;

  // legacy: email
  snap = await db
    .collection(colName)
    .where('email', '==', emailLower)
    .limit(1)
    .get();
  if (!snap.empty) return snap;

  return null as any;
}

async function getUserDocByEmailAny(
  emailLower: string
): Promise<DocumentSnapshot | null> {
  let snap = await db
    .collection(USERS_COL)
    .where('emailLower', '==', emailLower)
    .limit(1)
    .get();
  if (!snap.empty) return snap.docs[0];

  snap = await db
    .collection(USERS_COL)
    .where('email', '==', emailLower)
    .limit(1)
    .get();
  if (!snap.empty) return snap.docs[0];

  return null;
}

/** Server-side fallback check against Firebase after hosted reset */
async function verifyWithFirebase(
  email: string,
  password: string
): Promise<boolean> {
  const apiKey = FIREBASE_WEB_API_KEY;
  if (!/^AIza/.test(apiKey)) {
    console.error('APP_FIREBASE_WEB_API_KEY invalid or missing at runtime');
    return false;
  }
  
  // use the current endpoint name
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;
  try {
    const resp = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    });
    if (!resp.ok) {
      const text = await resp.text().catch(() => '');
      console.warn('verifyWithFirebase failed:', resp.status, text);
      return false;
    }
    const data: any = await resp.json();
    return !!data?.idToken;
  } catch (e) {
    console.error('verifyWithFirebase error:', e);
    return false;
  }
}

// ── Controllers ─────────────────────────────────────────────────────────────-

// POST /api/auth/register
export const register = async (req: Request, res: Response): Promise<Response> => {
  try {
    let {
      empid,
      name,
      email,
      password,
      role = 'employee',
      status = 'active',
    } = req.body || {};
    email = normEmail(email || '');
    empid = String(empid || '').trim();
    name = String(name || '').trim();
    role = String(role || 'employee').trim().toLowerCase();
    status = String(status || 'active').trim().toLowerCase();

    if (!name || !email || !password) {
      return res
        .status(400)
        .json({ error: 'Name, email and password are required' });
    }
    if (!okRoles.has(role)) {
      return res
        .status(400)
        .json({ error: 'Role must be "employee" or "admin"' });
    }

    const byEmail = await db
      .collection(USERS_COL)
      .where('emailLower', '==', email)
      .limit(1)
      .get();
    if (!byEmail.empty)
      return res.status(400).json({ error: 'Email is already in use' });

    if (empid) {
      const byEmp = await db
        .collection(USERS_COL)
        .where('empid', '==', empid)
        .limit(1)
        .get();
      if (!byEmp.empty)
        return res.status(400).json({ error: 'Employee ID already exists' });
    }

    const hash = await bcrypt.hash(password, 10);
    const now = new Date();

    const userId = uuidv4();
    await db.collection(USERS_COL).doc(userId).set({
      empid: empid || null,
      empId: empid || null, // keep both keys for compatibility
      name,
      email,
      emailLower: email,
      password: hash,
      passwordHash: hash,
      hashedPassword: hash,
      role,
      status,
      createdAt: now,
      updatedAt: now,
    });

    const token = issueToken({ userId, email, role, empid: empid || null });

    return res.status(201).json({
      id: userId,
      name,
      email,
      role,
      empid: empid || null,
      status,
      token,
      tokenType: 'Bearer',
      expiresIn: JWT_EXPIRES,
    });
  } catch (error) {
    console.error('Registration error:', error);
    return res.status(500).json({ error: 'Failed to register user' });
  }
};

// POST /api/auth/login
export const login = async (req: Request, res: Response): Promise<Response> => {
  try {
    const incoming = String(req.body.email || '');
    const email = normEmail(incoming);
    const { password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    // 1) USERS first
    const userSnap = await getByEmail(USERS_COL, email);
    if (userSnap && !userSnap.empty) {
      const doc = userSnap.docs[0];
      const user: any = doc.data();

   const storedHash =
  user.password || user.passwordHash || user.hashedPassword || '';

let match = false;

// 1) Always try local bcrypt first if stored hash exists
if (storedHash) {
  try {
    match = await bcrypt.compare(password, storedHash);
  } catch {}
}

// 2) If bcrypt fails → try Firebase
if (!match) {
  const ok = await verifyWithFirebase(email, password);
  if (!ok) return res.status(401).json({ error: 'Invalid email or password' });

  // Firebase verified, rotate local password hash to new one
  try {
    await rotatePassword({
      db,
      userId: doc.id,
      oldHash: storedHash || null,
      newPlainPassword: password,
      source: 'firebase_reset',
      keepLast: 5,
    });
  } catch (e) {
    console.warn('Password rotate failed:', e);
  }

  match = true;
}

      // === END USERS branch ===

      if (user.status && user.status !== 'active') {
        return res.status(403).json({ error: 'Account is not active' });
      }

      const role = String(user.role || 'employee').toLowerCase();
      if (!okRoles.has(role)) {
        return res.status(403).json({ error: 'Invalid role on account' });
      }

      // ensure empid populated
      let userEmpid = pickEmpId(user);
      if (!userEmpid) {
        const empQ = await db
          .collection(EMPS_COL)
          .where('emailLower', '==', email)
          .limit(1)
          .get();
        if (!empQ.empty) {
          userEmpid = pickEmpId(empQ.docs[0].data());
          if (userEmpid) {
            await doc.ref.set(
              { empid: userEmpid, empId: userEmpid, updatedAt: new Date() },
              { merge: true }
            );
          }
        }
      }

      const token = issueToken({
        userId: doc.id,
        email: user.email || incoming.trim(),
        role,
        empid: userEmpid || null,
      });

      return res.json({
        message: 'Login successful',
        token,
        tokenType: 'Bearer',
        expiresIn: JWT_EXPIRES,
        role,
        uid: doc.id,
        empid: userEmpid || null,
        name: user.name || user.fullName || '',
        user: {
          id: doc.id,
          name: user.name || user.fullName || '',
          email: user.email || incoming.trim(),
          role,
          empid: userEmpid || null,
          empId: userEmpid || null,
          status: user.status || 'active',
        },
      });
    }

    // 2) EMPLOYEES fallback
    const empSnap = await getByEmail(EMPS_COL, email);
    if (!empSnap || empSnap.empty) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const empDoc = empSnap.docs[0];
    const emp: any = empDoc.data();

    const stored = emp.password || '';
    let passOK = false;
    if (stored) {
      passOK = isBcryptHash(stored)
        ? await bcrypt.compare(password, stored)
        : stored === password;
    }

    // === EMPLOYEES fallback: try Firebase if local fails ===
    if (!passOK) {
      const ok = await verifyWithFirebase(email, password);
      if (!ok) return res.status(401).json({ error: 'Invalid email or password' });
      // else continue as usual to mirror/create USERS doc etc. and rotate below
    }
    // === END EMPLOYEES fallback ===

    if (emp.status && emp.status !== 'active') {
      return res.status(403).json({ error: 'Account is not active' });
    }

    // Mirror into USERS so future logins are consistent
    let mirror = await getByEmail(USERS_COL, email);
    let mirrorDoc: DocumentSnapshot | null = null;

    if (mirror && !mirror.empty) {
      mirrorDoc = mirror.docs[0];

      // When Firebase accepted, rotate existing USERS doc with the entered password
      if (!passOK && mirrorDoc) {
        try {
          const prev =
            (mirrorDoc.get('password') ||
              mirrorDoc.get('passwordHash') ||
              mirrorDoc.get('hashedPassword') ||
              null) as string | null;

          await rotatePassword({
            db,
            userId: mirrorDoc.id,
            oldHash: prev,
            newPlainPassword: password,
            source: 'firebase_reset',
            keepLast: 5,
          });
        } catch (e) {
          console.warn('rotatePassword failed (EMPLOYEES existing mirror):', e);
        }
      }
    } else {
      // If authenticated via Firebase or local, create USERS mirror with the entered password
      const hash = isBcryptHash(stored) ? stored : await bcrypt.hash(password, 10);
      const now = new Date();
      const empIdVal = pickEmpId(emp);
      const ref = await db.collection(USERS_COL).add({
        empid: empIdVal || null,
        empId: empIdVal || null,
        name: emp.name || emp.fullName || '',
        email: emp.email || incoming.trim(),
        emailLower: email,
        password: hash,
        passwordHash: hash,
        hashedPassword: hash,
        role: 'employee',
        status: 'active',
        createdAt: now,
        updatedAt: now,
        authSource: !passOK ? 'firebase' : 'local',
      });
      mirrorDoc = await ref.get();
    }

    const u = mirrorDoc!.data() as any;
    const finalEmpid = pickEmpId(u) || pickEmpId(emp);

    const token = issueToken({
      userId: mirrorDoc!.id,
      email: u.email || incoming.trim(),
      role: 'employee',
      empid: finalEmpid || null,
    });

    return res.json({
      message: 'Login successful',
      token,
      tokenType: 'Bearer',
      expiresIn: JWT_EXPIRES,
      role: 'employee',
      uid: mirrorDoc!.id,
      empid: finalEmpid || null,
      name: u.name || emp.name || '',
      user: {
        id: mirrorDoc!.id,
        name: u.name || emp.name || '',
        email: u.email || incoming.trim(),
        role: 'employee',
        empid: finalEmpid || null,
        empId: finalEmpid || null,
        status: u.status || emp.status || 'active',
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({ error: 'Failed to login' });
  }
};

// GET /api/auth/me
export const getMe = async (req: Request, res: Response): Promise<Response> => {
  try {
    const userId = (req as any).user?.userId;
    const email = normEmail((req as any).user?.email || '');
    if (!userId && !email)
      return res.status(401).json({ error: 'Unauthorized' });

    // Try USERS by id
    let doc: DocumentSnapshot | null = null;
    if (userId) {
      const d = await db.collection(USERS_COL).doc(userId).get();
      if (d.exists) doc = d;
    }
    // Fallback: USERS by emailLower
    if (!doc && email) {
      const q = await db
        .collection(USERS_COL)
        .where('emailLower', '==', email)
        .limit(1)
        .get();
      if (!q.empty) doc = q.docs[0];
    }

    if (doc) {
      const user = sanitizeUser(doc.id, doc.data());
      const eid =
        (user as any).empid ??
        (user as any).empId ??
        (user as any).employeeId ??
        null;
      if (eid && !(user as any).empid) (user as any).empid = eid;
      if (eid && !(user as any).empId) (user as any).empId = eid;

      if ((user as any).empid) {
        const empSnap = await db
          .collection(EMPS_COL)
          .where('empid', '==', (user as any).empid)
          .limit(1)
          .get();
        if (!empSnap.empty) {
          const emp = empSnap.docs[0].data();
          delete (emp as any).password;
          (user as any).employeeProfile = emp;
        }
      }
      return res.json(user);
    }

    // Last resort: employees by emailLower
    if (email) {
      const empSnap = await db
        .collection(EMPS_COL)
        .where('emailLower', '==', email)
        .limit(1)
        .get();
      if (!empSnap.empty) {
        const eDoc = empSnap.docs[0];
        const emp = eDoc.data();
        delete (emp as any).password;
        const eid = pickEmpId(emp);
        return res.json({
          id: eDoc.id,
          email,
          role: 'employee',
          empid: eid || null,
          empId: eid || null,
          name: (emp as any).name || (emp as any).fullName || '',
          employeeProfile: emp,
        });
      }
    }

    return res.status(404).json({ error: 'User not found' });
  } catch (err) {
    console.error('getMe error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

// POST /api/auth/change-password  { newPassword }
export const changePassword = async (req: Request, res: Response): Promise<Response> => {
  try {
    const userId = (req as any).user?.userId;
    const tokenEmail = normEmail((req as any).user?.email || '');
    const newPassword = String(req.body?.newPassword || '').trim();

    if (!userId || !newPassword) {
      return res.status(400).json({ error: 'newPassword and token are required' });
    }
    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }

    // 1) Load USERS doc
    const userDoc = await db.collection(USERS_COL).doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    const user = userDoc.data() as any;

    // 2) Resolve account email (for Firebase UID lookup)
    const emailLower = normEmail(user.emailLower || user.email || tokenEmail);
    if (!emailLower) {
      return res.status(500).json({ error: 'Account email missing on user document' });
    }

    // 3) Update Firebase Auth password by email (correct UID)
    try {
      const fbUser = await auth.getUserByEmail(emailLower);
      await auth.updateUser(fbUser.uid, { password: newPassword });
    } catch (e) {
      console.warn('Firebase Auth update by email failed:', e);
      return res.status(500).json({ error: 'Failed to update password in Firebase Auth' });
    }

    // 4) Rotate local hash in Firestore (so local bcrypt also matches)
    const prevHash =
      user.password || user.passwordHash || user.hashedPassword || null;

    await rotatePassword({
      db,
      userId,
      oldHash: prevHash,
      newPlainPassword: newPassword,
      source: 'self_change',
      keepLast: 5,
    });

    // 5) Mark as local (so bcrypt is tried first) and clear mustChangePassword
    await userDoc.ref.set(
      { authSource: 'local', mustChangePassword: false, updatedAt: new Date() },
      { merge: true }
    );

    return res.json({ message: 'Password changed successfully' });
  } catch (err) {
    console.error('changePassword error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

// ── Admin helpers ────────────────────────────────────────────────────────────

// POST /api/auth/admin/create-employee-login  { empid, email?, password? }
export const createEmployeeLogin = async (
  req: Request,
  res: Response
): Promise<Response> => {
  try {
    let { empid, email, password } = req.body || {};
    empid = String(empid || '').trim();
    email = normEmail(email || '');
    if (!empid) return res.status(400).json({ error: 'empid is required' });

    const empQ = await db
      .collection(EMPS_COL)
      .where('empid', '==', empid)
      .limit(1)
      .get();
    if (empQ.empty) return res.status(404).json({ error: 'Employee not found' });
    const emp = empQ.docs[0].data() as any;

    const name = String(emp.name || emp.fullName || '').trim();
    if (!email) email = normEmail(emp.email || '');
    if (!email)
      return res
        .status(400)
        .json({ error: 'email is required (not found on employee record)' });

    const existsByEmail = await db
      .collection(USERS_COL)
      .where('emailLower', '==', email)
      .limit(1)
      .get();
    if (!existsByEmail.empty)
      return res
        .status(409)
        .json({ error: 'Login already exists for this email' });

    const existsByEmpid = await db
      .collection(USERS_COL)
      .where('empid', '==', empid)
      .limit(1)
      .get();
    if (!existsByEmpid.empty)
      return res.status(409).json({ error: 'Login already exists for this empid' });

    const tempPassword = `${empid}@123`;
    const finalPassword = String(password || tempPassword);
    const hash = await bcrypt.hash(finalPassword, 10);
    const now = new Date();

    const docRef = await db.collection(USERS_COL).add({
      empid,
      empId: empid, // keep both keys
      name,
      email,
      emailLower: email,
      password: hash,
      passwordHash: hash,
      hashedPassword: hash,
      role: 'employee',
      status: 'active',
      mustChangePassword: !password,
      createdAt: now,
      updatedAt: now,
    });

    return res.json({
      message: 'Login enabled for employee',
      userId: docRef.id,
      tempPassword: !password ? tempPassword : undefined,
    });
  } catch (err) {
    console.error('createEmployeeLogin error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

// POST /api/auth/admin/backfill-employee-logins
export const backfillEmployeesToUsers = async (
  req: Request,
  res: Response
): Promise<Response> => {
  try {
    const empSnap = await db.collection(EMPS_COL).get();
    const created: any[] = [];
    const updatedEmp: any[] = [];

    for (const d of empSnap.docs) {
      const e = d.data() as any;
      const empidRaw = pickEmpId(e);
      const empid = empidRaw ? String(empidRaw) : '';
      const emailLower = normEmail(e.email || '');
      const name = String(e.name || e.fullName || '').trim();
      if (!empid || !emailLower) {
        await d.ref.set({ emailLower }, { merge: true });
        continue;
      }

      if (!e.emailLower || e.emailLower !== emailLower) {
        await d.ref.set({ emailLower }, { merge: true });
        updatedEmp.push({ empid, emailLower });
      }

      const exists = await db
        .collection(USERS_COL)
        .where('emailLower', '==', emailLower)
        .limit(1)
        .get();
      if (!exists.empty) continue;

      const existsEmp = await db
        .collection(USERS_COL)
        .where('empid', '==', empid)
        .limit(1)
        .get();
      if (!existsEmp.empty) continue;

      const temp = `${empid}@123`;
      const hash = await bcrypt.hash(temp, 10);
      const now = new Date();

      const ref = await db.collection(USERS_COL).add({
        empid,
        empId: empid, // both keys
        name,
        email: e.email || emailLower,
        emailLower,
        password: hash,
        passwordHash: hash,
        hashedPassword: hash,
        role: 'employee',
        status: 'active',
        mustChangePassword: true,
        createdAt: now,
        updatedAt: now,
      });

      created.push({
        userId: ref.id,
        empid,
        email: e.email || emailLower,
        tempPassword: temp,
      });
    }

    return res.json({
      message: 'Backfill complete',
      createdCount: created.length,
      normalizedEmployees: updatedEmp.length,
      created,
    });
  } catch (err) {
    console.error('backfillEmployeesToUsers error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

// ── Forgot password via Firebase reset link ONLY ─────────────────────────────
// POST /api/auth/forgot-password/request-link  { email }
export const requestPasswordResetLink = async (
  req: Request,
  res: Response
): Promise<Response> => {
  try {
    const email = normEmail(req.body.email || '');
    if (!email) return res.status(400).json({ error: 'Email is required' });

    // Ensure user exists (users or employees)
    const userDoc = await getUserDocByEmailAny(email);
    if (!userDoc) {
      const empQ = await db
        .collection(EMPS_COL)
        .where('emailLower', '==', email)
        .limit(1)
        .get();
      if (empQ.empty) return res.status(404).json({ error: 'User not found' });
    }

    // Generate Firebase password reset link with continue URL to your hosted page
    const link = await auth.generatePasswordResetLink(email, {
      url: RESET_CONTINUE_URL,
      handleCodeInApp: true, // hosted page should initialize same PROJECT
    });

    // If SMTP configured, send email; else return link for testing
    if (mailer) {
      const from =
        process.env.SMTP_FROM || `SERV App <${process.env.SMTP_USER}>`;
      await mailer.sendMail({
        from,
        to: email,
        subject: 'Reset your SERV password',
        html: `
          <p>Hello,</p>
          <p>Follow this link to reset your SERV password for <b>${email}</b>:</p>
          <p><a href="${link}">Reset your password</a></p>
          <p>If you didn’t ask to reset your password, you can ignore this email.</p>
          <p>Thanks,<br/>Your SERV team</p>
        `,
        text: `Reset your password: ${link}`,
      });
      return res.json({ message: 'Reset email sent' });
    } else {
      return res.json({
        message: 'Mailer not configured; use link directly',
        link,
      });
    }
  } catch (err: any) {
    console.error('requestPasswordResetLink error:', err);
    return res
      .status(500)
      .json({ error: err.message || 'Internal server error' });
  }
};

// ── Legacy convenience (kept) ────────────────────────────────────────────────
// POST /api/auth/forgot-password { email, newPassword }
export const forgotPassword = async (
  req: Request,
  res: Response
): Promise<Response> => {
  if (!req.body?.email || !req.body?.newPassword) {
    return res.status(400).json({
      error:
        'Provide email and newPassword or use /forgot-password/request-link.',
    });
  }
  return changePassword(req, res);
};

// ── Simple profile endpoints (compat) ────────────────────────────────────────
export const getProfile = async (
  req: Request & { user?: { userId: string } },
  res: Response
) => getMe(req as any, res);

export const updateProfile = async (
  req: Request & { user?: { userId: string } },
  res: Response
) => res.json({ message: 'Profile updated successfully' }); // stub or implement as needed

export const resetPassword = async () => {
  /* unused */
};
