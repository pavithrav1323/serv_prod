// functions/src/controllers/reasonMasterController.ts
import { Request, Response } from "express";
import * as admin from "firebase-admin";

const db = admin.firestore();
const TYPES_COL   = "reason_types";
const REASONS_COL = "reasons";

/* --------------------------- helpers --------------------------- */
const safe = (v: any) => String(v ?? "").trim();
const now  = () => admin.firestore.FieldValue.serverTimestamp();

function ok(res: Response, data: any, code = 200) {
  return res.status(code).json(data);
}
function bad(res: Response, msg = "Bad request", code = 400) {
  return res.status(code).json({ status: "error", message: msg });
}
function notfound(res: Response, msg = "Not found") {
  return res.status(404).json({ status: "error", message: msg });
}

/* ----------------------- Reason Types CRUD ---------------------- */
export async function listTypes(_req: Request, res: Response) {
  const snap = await db.collection(TYPES_COL).where("deleted", "==", false).get();
  const items = snap.docs.map(d => ({ id: d.id, ...(d.data() as any) }));
  return ok(res, items);
}

export async function createType(req: Request, res: Response) {
  const name = safe(req.body?.name);
  if (!name) return bad(res, "Field `name` is required");

  const dup = await db.collection(TYPES_COL)
    .where("name_lower", "==", name.toLowerCase())
    .where("deleted", "==", false)
    .limit(1).get();
  if (!dup.empty) return bad(res, "Type already exists");

  const doc = await db.collection(TYPES_COL).add({
    name,
    name_lower: name.toLowerCase(),
    deleted: false,
    createdAt: now(),
    updatedAt: now(),
  });
  const data = (await doc.get()).data();
  return ok(res, { id: doc.id, ...(data as any) }, 201);
}

export async function deleteType(req: Request, res: Response) {
  const id = safe(req.params.id);
  const ref = db.collection(TYPES_COL).doc(id);
  const snap = await ref.get();
  if (!snap.exists) return notfound(res, "Type not found");

  // Soft delete type
  await ref.update({ deleted: true, updatedAt: now() });

  // Soft delete reasons for this type as well
  const batch = db.batch();
  const rs = await db.collection(REASONS_COL)
    .where("typeId", "==", id)
    .where("deleted", "==", false)
    .get();
  rs.forEach(d => batch.update(d.ref, { deleted: true, updatedAt: now() }));
  await batch.commit();

  return ok(res, { status: "ok", message: "Type and its reasons soft-deleted" });
}

/* ------------------------- Reasons CRUD ------------------------- */

// GET /api/reasons?search=..&typeId=..&limit=50&cursor=docId
export async function listReasons(req: Request, res: Response) {
  const { search, typeId, limit = 50, cursor } = req.query as any;

  // First try the ideal (indexed) query
  try {
    let q: FirebaseFirestore.Query = db.collection(REASONS_COL)
      .where("deleted", "==", false)
      .orderBy("createdAt", "desc");

    if (typeId) q = q.where("typeId", "==", safe(typeId));

    if (cursor) {
      const cdoc = await db.collection(REASONS_COL).doc(String(cursor)).get();
      if (cdoc.exists) q = q.startAfter(cdoc);
    }

    const snap = await q.limit(Number(limit) || 50).get();
    let items = snap.docs.map(d => ({ id: d.id, ...(d.data() as any) }));

    if (search) {
      const s = String(search).toLowerCase();
      items = items.filter(r =>
        String(r.reason ?? "").toLowerCase().includes(s) ||
        String(r.typeName ?? "").toLowerCase().includes(s)
      );
    }

    const nextCursor = snap.docs.length ? snap.docs[snap.docs.length - 1].id : null;
    return ok(res, { items, nextCursor });
  } catch (err: any) {
    // If there is no composite index, Firestore throws FAILED_PRECONDITION (code 9)
    if (err?.code !== 9 /* FAILED_PRECONDITION */) {
      console.error('listReasons unexpected error:', err);
      return res.status(500).json({ status: 'error', message: err?.message || 'Internal error' });
    }
  }

  // Fallback (no composite index): fetch without orderBy and sort in memory
  try {
    let q: FirebaseFirestore.Query = db.collection(REASONS_COL)
      .where("deleted", "==", false);

    if (typeId) q = q.where("typeId", "==", safe(typeId));

    const snap = await q.limit(500).get(); // safe cap; adjust as needed
    let items = snap.docs.map(d => ({ id: d.id, ...(d.data() as any) }));

    // Sort locally by createdAt desc
    items.sort((a: any, b: any) => {
      const ta = (a?.createdAt?._seconds ?? a?.createdAt?.seconds ?? 0);
      const tb = (b?.createdAt?._seconds ?? b?.createdAt?.seconds ?? 0);
      return tb - ta;
    });

    if (search) {
      const s = String(search).toLowerCase();
      items = items.filter(r =>
        String(r.reason ?? "").toLowerCase().includes(s) ||
        String(r.typeName ?? "").toLowerCase().includes(s)
      );
    }

    // Fallback pagination omitted (no stable server-side order without index)
    return ok(res, { items, nextCursor: null });
  } catch (err: any) {
    console.error('listReasons fallback error:', err);
    return res.status(500).json({ status: 'error', message: err?.message || 'Internal error' });
  }
}

// POST /api/reasons  { typeId, reason, createdBy? }
export async function createReason(req: Request, res: Response) {
  const typeId = safe(req.body?.typeId);
  const reason = safe(req.body?.reason);
  const createdBy = safe((req as any).user?.email ?? req.body?.createdBy);

  if (!typeId) return bad(res, "Field `typeId` is required");
  if (!reason) return bad(res, "Field `reason` is required");

  const typeDoc = await db.collection(TYPES_COL).doc(typeId).get();
  if (!typeDoc.exists || (typeDoc.data() as any)?.deleted) return bad(res, "Invalid typeId");

  const typeName = (typeDoc.data() as any).name;

  const doc = await db.collection(REASONS_COL).add({
    typeId,
    typeName,
    reason,
    createdBy: createdBy || null,
    deleted: false,
    createdAt: now(),
    updatedAt: now(),
  });

  const data = (await doc.get()).data();
  return ok(res, { id: doc.id, ...(data as any) }, 201);
}

// DELETE /api/reasons/:id
export async function deleteReason(req: Request, res: Response) {
  const id = safe(req.params.id);
  const ref = db.collection(REASONS_COL).doc(id);
  const snap = await ref.get();
  if (!snap.exists) return notfound(res, "Reason not found");

  await ref.update({ deleted: true, updatedAt: now() });
  return ok(res, { status: "ok", message: "Reason soft-deleted" });
}
