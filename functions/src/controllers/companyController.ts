import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const COMPANY_COLLECTION = 'companyProfile';

type TS = admin.firestore.Timestamp;

interface CompanyProfile {
  id?: string;
  adminEmail: string;      // email of the admin user (doc owner)
  adminEmailLower?: string;
  companyName: string;
  email: string;           // official company email (from form)
  emailLower?: string;
  phone: string;
  website?: string;
  logoUrl?: string;
  logoBase64?: string;
  adminName: string;
  designation: string;
  filled?: boolean;
  createdAt: TS;
  updatedAt: TS;
}

const normalizeEmail = (v: string | undefined | null) =>
  String(v || '').trim().toLowerCase();

const computeFilled = (p: Partial<CompanyProfile>) =>
  Boolean(p.companyName && p.email && p.phone && p.adminName && p.designation);

/** Try multiple ways to find a profile for a given admin email (lowercased). */
async function findProfileDoc(adminEmailLower: string) {
  // 1) Fast path: docId === admin email lower
  const byIdRef = db.collection(COMPANY_COLLECTION).doc(adminEmailLower);
  const byIdSnap = await byIdRef.get();
  if (byIdSnap.exists) return byIdSnap;

  // 2) Fallbacks (support older shapes)
  const tryQueries: Array<Promise<FirebaseFirestore.QuerySnapshot>> = [
    db.collection(COMPANY_COLLECTION).where('adminEmailLower', '==', adminEmailLower).limit(1).get(),
    db.collection(COMPANY_COLLECTION).where('adminEmail', '==', adminEmailLower).limit(1).get(),
    db.collection(COMPANY_COLLECTION).where('emailLower', '==', adminEmailLower).limit(1).get(),
    db.collection(COMPANY_COLLECTION).where('email', '==', adminEmailLower).limit(1).get(),
  ];

  for (const p of tryQueries) {
    const snap = await p;
    if (!snap.empty) return snap.docs[0];
  }

  return null;
}

export const saveCompanyProfile = async (req: Request, res: Response): Promise<Response> => {
  try {
    const tokenUser = (req as any).user;
    const adminEmailFromToken = normalizeEmail(tokenUser?.email);
    if (!adminEmailFromToken) {
      return res.status(401).json({ success: false, message: 'Unauthorized: token email missing' });
    }

    const {
      companyName,
      email,
      phone,
      website,
      adminName,
      designation,
      logoBase64,
      logoMimeType,
    } = (req.body || {}) as Partial<CompanyProfile> & { logoMimeType?: string };

    const required = { companyName, email, phone, adminName, designation };
    const missing = Object.entries(required).filter(([, v]) => !v).map(([k]) => k);
    if (missing.length) {
      return res.status(400).json({ success: false, error: 'Missing required fields', missingFields: missing });
    }

    const now = admin.firestore.Timestamp.now();
    const docRef = db.collection(COMPANY_COLLECTION).doc(adminEmailFromToken);

    const data: Partial<CompanyProfile> = {
      id: adminEmailFromToken,
      adminEmail: adminEmailFromToken,
      adminEmailLower: adminEmailFromToken,
      companyName: String(companyName),
      email: normalizeEmail(email),
      emailLower: normalizeEmail(email),
      phone: String(phone),
      website: website ? String(website) : '',
      adminName: String(adminName),
      designation: String(designation),
      updatedAt: now,
    };

    // derive/ensure "filled"
    data.filled = computeFilled(data);

    if (logoBase64 && logoMimeType) {
      const ok = ['image/jpeg', 'image/png', 'image/gif'].includes(logoMimeType);
      if (!ok) return res.status(400).json({ success: false, message: 'Only JPEG, PNG, GIF allowed' });

      const base64Data = (logoBase64.split(';base64,').pop() || logoBase64).trim();
      const sizeBytes = (base64Data.length * 3) / 4 - (base64Data.endsWith('==') ? 2 : base64Data.endsWith('=') ? 1 : 0);
      if (sizeBytes > 5 * 1024 * 1024) {
        return res.status(400).json({ success: false, message: 'Max image size 5MB' });
      }
      data.logoBase64 = `data:${logoMimeType};base64,${base64Data}`;
    }

    const prev = await docRef.get();
    if (!prev.exists) (data as any).createdAt = now;

    await docRef.set(data, { merge: true });
    const fresh = await docRef.get();

    return res.status(200).json({
      success: true,
      message: 'Company profile saved successfully',
      data: { id: fresh.id, ...fresh.data() },
      timestamp: now.toDate().toISOString(),
    });
  } catch (e: any) {
    console.error('saveCompanyProfile error:', e);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

export const checkCompanyProfile = async (req: Request, res: Response): Promise<Response> => {
  try {
    const tokenUser = (req as any).user;
    const adminEmail = normalizeEmail(tokenUser?.email);
    if (!adminEmail) {
      return res.status(400).json({ success: false, filled: false, error: 'User email not found in token' });
    }

    const snap = await findProfileDoc(adminEmail);
    if (!snap) {
      return res.status(200).json({ success: true, filled: false, data: null });
    }

    const raw = snap.data() || {};
    const filled = typeof raw.filled === 'boolean' ? raw.filled : computeFilled(raw);

    return res.status(200).json({
      success: true,
      filled,
      data: { id: snap.id, ...raw },
    });
  } catch (error) {
    console.error('Error in checkCompanyProfile:', error);
    return res.status(500).json({ success: false, filled: false, error: 'Internal server error' });
  }
};

export const getCompanyProfile = async (req: Request, res: Response): Promise<Response> => {
  try {
    const tokenUser = (req as any).user;
    const adminEmail = normalizeEmail(tokenUser?.email);
    if (!adminEmail) {
      return res.status(400).json({ success: false, message: 'User email not found in token' });
    }

    const snap = await findProfileDoc(adminEmail);
    if (!snap) {
      return res.status(404).json({ success: false, message: 'Company profile not found' });
    }

    return res.status(200).json({ success: true, data: { id: snap.id, ...snap.data() } });
  } catch (e: any) {
    console.error('getCompanyProfile error:', e);
    return res.status(500).json({ success: false, message: 'Failed to fetch company profile' });
  }
};
