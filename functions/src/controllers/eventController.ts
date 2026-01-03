import { Request, Response } from 'express';
import path from 'path';
import fs from 'fs';
import { randomUUID } from 'crypto';

// Helper to safely trim fields
const getTrim = (obj: any, key: string): string => (obj?.[key] ?? '').toString().trim();

// Ensure uploads directory exists (note: on serverless, use /tmp for persistence)
const uploadsDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Minimal type for express-fileupload's UploadedFile
type UploadedFile = {
  name: string;
  mv: (dest: string, cb?: (err?: any) => void) => void; // mv uses callback; we'll promisify
  mimetype?: string;
  size?: number;
};

// Pick first file if array, else the single file, else null
const pickFirst = <T>(f: T | T[] | undefined | null): T | null =>
  (Array.isArray(f) ? (f[0] ?? null) : (f ?? null)) as T | null;

const moveFile = (file: UploadedFile, destPath: string): Promise<void> =>
  new Promise((resolve, reject) => {
    try {
      file.mv(destPath, (err?: any) => (err ? reject(err) : resolve()));
    } catch (e) {
      reject(e);
    }
  });

export const createEvent = async (req: Request, res: Response) => {
  try {
    // Helpful logs while integrating
    console.log('[events:create] content-type:', req.headers['content-type']);
    console.log('[events:create] body keys:', Object.keys((req.body as any) || {}));
    console.log('[events:create] files keys:', (req as any).files ? Object.keys((req as any).files) : '(none)');

    const db = (req.app.locals as any).db as FirebaseFirestore.Firestore;

    const title       = getTrim(req.body, 'title');
    const description = getTrim(req.body, 'description');
    const location    = getTrim(req.body, 'location');
    const fromDate    = getTrim(req.body, 'fromDate'); // yyyy-MM-dd
    const toDate      = getTrim(req.body, 'toDate');

    const missing: string[] = [];
    if (!title)       missing.push('title');
    if (!description) missing.push('description');
    if (!location)    missing.push('location');
    if (!fromDate)    missing.push('fromDate');
    if (!toDate)      missing.push('toDate');

    if (missing.length) {
      return res.status(400).json({ error: `Missing: ${missing.join(', ')}` });
    }

    let imageUrl: string | null = null;
    let fileUrl:  string | null = null;

    // Note: using express-fileupload (req.files), typed as any here
    const files: any = (req as any).files;

    if (files?.image) {
      const image = pickFirst<UploadedFile>(files.image);
      if (image) {
        const imageName = `${randomUUID()}${path.extname(image.name)}`;
        const imagePath = path.join(uploadsDir, imageName);
        await moveFile(image, imagePath);
        imageUrl = `/uploads/${imageName}`;
      }
    }

    if (files?.file) {
      const f = pickFirst<UploadedFile>(files.file);
      if (f) {
        const fileName = `${randomUUID()}${path.extname(f.name)}`;
        const filePath = path.join(uploadsDir, fileName);
        await moveFile(f, filePath);
        fileUrl = `/uploads/${fileName}`;
      }
    }

    const eventDoc = {
      title,
      description,
      location,
      fromDate, // stored as string "yyyy-MM-dd" (lex-sortable)
      toDate,   // stored as string "yyyy-MM-dd"
      imageUrl,
      fileUrl,
      createdAt: new Date(),
    };

    const ref = await db.collection('events').add(eventDoc);
    return res.status(201).json({ id: ref.id, ...eventDoc });
  } catch (err: any) {
    console.error('[events:create] error:', err);
    return res.status(500).json({ error: err.message || String(err) });
  }
};

export const getAllEvents = async (req: Request, res: Response) => {
  try {
    const db = (req.app.locals as any).db as FirebaseFirestore.Firestore;
    const snap = await db.collection('events').orderBy('fromDate', 'desc').get();
    const data = snap.docs.map((d) => ({ id: d.id, ...(d.data() as Record<string, unknown>) }));
    return res.json(data);
  } catch (err: any) {
    console.error('[events:getAll] error:', err);
    return res.status(500).json({ error: err.message || String(err) });
  }
};

export const deleteEvent = async (req: Request, res: Response) => {
  try {
    const db = (req.app.locals as any).db as FirebaseFirestore.Firestore;
    const { id } = req.params as { id: string };
    await db.collection('events').doc(id).delete();
    return res.status(200).json({ message: 'Event deleted successfully' });
  } catch (err: any) {
    console.error('[events:delete] error:', err);
    return res.status(500).json({ error: err.message || String(err) });
  }
};
