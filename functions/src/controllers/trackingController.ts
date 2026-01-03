// import { Request, Response } from 'express';
// import { db } from '../config/firebase';

// export type AuthUser = {
//   userId: string;
//   email: string;
//   role: string;
//   empid?: string | null;
//   uid?: string; // compat
// };

// type TrackPoint = { lat: number; lng: number; ts: string; accuracy?: number; source?: string };

// type TrackDayDoc = {
//   id: string;             // empid_YYYY-MM-DD
//   empid: string;
//   dateIso: string;        // YYYY-MM-DD
//   pathMap: TrackPoint[];
//   startedAt?: string;     // ISO
//   endedAt?: string | null;
//   lastUpdateAt: string;   // ISO
// };

// const COL = 'tracking';

// function todayIsoUTC(): string {
//   return new Date().toISOString().slice(0, 10);
// }

// // Prefer explicit empid (header/query/body) and fall back to token.
// // This lets admins view/save for any employee.
// function pickEmpId(req: Request): string {
//   const fromHeader = String(req.headers['x-empid'] || '').trim();
//   const fromQuery  = String(req.query.empid || '').trim();
//   const fromBody   = String((req.body || {}).empid || '').trim();
//   const fromToken  = ((req.user as AuthUser | undefined)?.empid || '').trim();
//   const emp = fromHeader || fromQuery || fromBody || fromToken;
//   if (!emp) throw new Error('empid missing (token/header/query/body)');
//   return emp;
// }

// function dateFromReq(req: Request): string {
//   const q = (req.query.dateIso as string) || (req.body?.dateIso as string) || '';
//   if (/^\d{4}-\d{2}-\d{2}$/.test(q)) return q;
//   return todayIsoUTC();
// }

// function docId(empid: string, dateIso: string): string {
//   return `${empid}_${dateIso}`;
// }

// function pointFromBody(body: any): TrackPoint {
//   const lat = Number(body?.lat);
//   const lng = Number(body?.lng);
//   const accuracy = (Number.isFinite(Number(body?.accuracy)) ? Number(body?.accuracy) : undefined);
//   const source = (body?.source ? String(body.source) : undefined);

//   if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
//     throw new Error('lat/lng required as numbers');
//   }
//   return { lat, lng, ts: new Date().toISOString(), accuracy, source };
// }

// /** POST /api/tracking/check-in */
// export async function trackingCheckIn(req: Request, res: Response) {
//   try {
//     const empid = pickEmpId(req);
//     const dateIso = dateFromReq(req);
//     const id = docId(empid, dateIso);
//     const now = new Date().toISOString();

//     const ref = db.collection(COL).doc(id);

//     const data: TrackDayDoc = {
//       id,
//       empid,
//       dateIso,
//       pathMap: [],
//       startedAt: now,
//       endedAt: null,
//       lastUpdateAt: now,
//     };

//     await ref.set(data, { merge: true });
//     return res.status(200).json({ ok: true, id, empid, dateIso });
//   } catch (e: any) {
//     return res.status(400).json({ error: e?.message || String(e) });
//   }
// }

// /** POST /api/tracking/pos  — NO SKIP. Always append. */
// export async function trackingAppendPos(req: Request, res: Response) {
//   try {
//     const empid = pickEmpId(req);
//     const dateIso = dateFromReq(req);
//     const id = docId(empid, dateIso);
//     const pt = pointFromBody(req.body);
//     const nowIso = new Date().toISOString();

//     const ref = db.collection(COL).doc(id);

//     await db.runTransaction(async (tx) => {
//       const snap = await tx.get(ref);

//       if (!snap.exists) {
//         const data: TrackDayDoc = {
//           id,
//           empid,
//           dateIso,
//           pathMap: [pt],
//           startedAt: nowIso,
//           endedAt: null,
//           lastUpdateAt: nowIso,
//         };
//         tx.set(ref, data);
//         return;
//       }

//       const data = snap.data() as TrackDayDoc;
//       const list = Array.isArray(data.pathMap) ? data.pathMap : [];

//       tx.update(ref, {
//         pathMap: [...list, pt],    // <- always append; client controls cadence
//         lastUpdateAt: nowIso,
//       });
//     });

//     return res.status(200).json({ ok: true, id, added: pt });
//   } catch (e: any) {
//     return res.status(400).json({ error: e?.message || String(e) });
//   }
// }

// /** POST /api/tracking/check-out */
// export async function trackingCheckOut(req: Request, res: Response) {
//   try {
//     const empid = pickEmpId(req);
//     const dateIso = dateFromReq(req);
//     const id = docId(empid, dateIso);
//     const ref = db.collection(COL).doc(id);

//     const now = new Date().toISOString();
//     await ref.set({ endedAt: now, lastUpdateAt: now } as Partial<TrackDayDoc>, { merge: true });

//     return res.status(200).json({ ok: true, id, endedAt: now });
//   } catch (e: any) {
//     return res.status(400).json({ error: e?.message || String(e) });
//   }
// }

// /** GET /api/tracking/day?dateIso=YYYY-MM-DD */
// export async function trackingGetDay(req: Request, res: Response) {
//   try {
//     const empid = pickEmpId(req);
//     const dateIso = dateFromReq(req);
//     const id = docId(empid, dateIso);

//     const snap = await db.collection(COL).doc(id).get();
//     if (!snap.exists) {
//       const empty: TrackDayDoc = {
//         id,
//         empid,
//         dateIso,
//         pathMap: [],
//         endedAt: null,
//         lastUpdateAt: new Date().toISOString(),
//       };
//       return res.json({ ok: true, data: empty });
//     }
//     return res.json({ ok: true, data: snap.data() });
//   } catch (e: any) {
//     return res.status(400).json({ error: e?.message || String(e) });
//   }
// }
import { Request, Response } from 'express';
import { db } from '../config/firebase';

export type AuthUser = {
  userId: string;
  email: string;
  role: string;
  empid?: string | null;
  uid?: string; // compat
};

type TrackPoint = { lat: number; lng: number; ts: string; accuracy?: number; source?: string };

type TrackDayDoc = {
  id: string;             // empid_YYYY-MM-DD
  empid: string;
  dateIso: string;        // YYYY-MM-DD
  pathMap: TrackPoint[];
  startedAt?: string;     // ISO
  endedAt?: string | null;
  lastUpdateAt: string;   // ISO
};

const COL = 'tracking';

function todayIsoUTC(): string {
  return new Date().toISOString().slice(0, 10);
}

// Prefer explicit empid (header/query/body) and fall back to token.
// This lets admins view/save for any employee.
function pickEmpId(req: Request): string {
  const fromHeader = String(req.headers['x-empid'] || '').trim();
  const fromQuery  = String(req.query.empid || '').trim();
  const fromBody   = String((req.body || {}).empid || '').trim();
  const fromToken  = ((req.user as AuthUser | undefined)?.empid || '').trim();
  const emp = fromHeader || fromQuery || fromBody || fromToken;
  if (!emp) throw new Error('empid missing (token/header/query/body)');
  return emp;
}

function dateFromReq(req: Request): string {
  const q = (req.query.dateIso as string) || (req.body?.dateIso as string) || '';
  if (/^\d{4}-\d{2}-\d{2}$/.test(q)) return q;
  return todayIsoUTC();
}

function docId(empid: string, dateIso: string): string {
  return `${empid}_${dateIso}`;
}

function pointFromBody(body: any): TrackPoint {
  const lat = Number(body?.lat);
  const lng = Number(body?.lng);
  const accuracy = (Number.isFinite(Number(body?.accuracy)) ? Number(body?.accuracy) : undefined);
  const source = (body?.source ? String(body.source) : undefined);

  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw new Error('lat/lng required as numbers');
  }
  return { lat, lng, ts: new Date().toISOString(), accuracy, source };
}

/* ---------- NEW: throttle helpers (strict 20 min) ---------- */
function minutesBetween(aIso: string, bIso: string) {
  return Math.abs((new Date(aIso).getTime() - new Date(bIso).getTime()) / 60000);
}
const MIN_TRACK_INTERVAL_MIN = 5;
// very small movement filter so we don't store duplicate same-spot updates
function distanceMeters(a: {lat:number; lng:number}, b: {lat:number; lng:number}) {
  const R = 6371000; // m
  const toRad = (x:number)=> x * Math.PI/180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const s1 = Math.sin(dLat/2), s2 = Math.sin(dLng/2);
  const aa = s1*s1 + Math.cos(toRad(a.lat))*Math.cos(toRad(b.lat))*s2*s2;
  return Math.round(R * (2 * Math.atan2(Math.sqrt(aa), Math.sqrt(1-aa))));
}
const MIN_MOVE_METERS = 0;

/** POST /api/tracking/check-in */
export async function trackingCheckIn(req: Request, res: Response) {
  try {
    const empid = pickEmpId(req);
    const dateIso = dateFromReq(req);
    const id = docId(empid, dateIso);
    const now = new Date().toISOString();

    const ref = db.collection(COL).doc(id);

    const data: TrackDayDoc = {
      id,
      empid,
      dateIso,
      pathMap: [],
      startedAt: now,
      endedAt: null,
      lastUpdateAt: now,
    };

    await ref.set(data, { merge: true });
    return res.status(200).json({ ok: true, id, empid, dateIso });
  } catch (e: any) {
    return res.status(400).json({ error: e?.message || String(e) });
  }
}

/** POST /api/tracking/pos  — STRICT: accept at most once every 20 minutes. */
export async function trackingAppendPos(req: Request, res: Response) {
  try {
    const empid = pickEmpId(req);
    const dateIso = dateFromReq(req);
    const id = docId(empid, dateIso);
    const pt = pointFromBody(req.body);
    const nowIso = new Date().toISOString();

    const ref = db.collection(COL).doc(id);

    let accepted = false;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);

      if (!snap.exists) {
        const data: TrackDayDoc = {
          id,
          empid,
          dateIso,
          pathMap: [pt],
          startedAt: nowIso,
          endedAt: null,
          lastUpdateAt: nowIso,
        };
        tx.set(ref, data);
        accepted = true;
        return;
      }

      const data = snap.data() as TrackDayDoc;
      const list = Array.isArray(data.pathMap) ? data.pathMap : [];
      const last = list.length ? list[list.length - 1] : null;

      let allow = false;
      if (!last) {
        allow = true;
      } else {
        const sinceMin = minutesBetween(pt.ts, last.ts);
        // STRICT time throttle
        allow = sinceMin >= MIN_TRACK_INTERVAL_MIN;

        // Optional: if last write was long ago BUT device hasn't moved at all, still skip
        if (allow && distanceMeters({lat:last.lat, lng:last.lng}, {lat:pt.lat, lng:pt.lng}) < MIN_MOVE_METERS) {
          // treat as duplicate at the same spot — keep lastUpdateAt only
          allow = false;
        }
      }

      // Debug log
      const lastPoint = last || { lat: 0, lng: 0, ts: '' };
      const distance = last 
        ? distanceMeters({lat: lastPoint.lat, lng: lastPoint.lng}, {lat: pt.lat, lng: pt.lng})
        : 0;
      const timeSinceLast = last ? minutesBetween(pt.ts, lastPoint.ts) : 0;
      
      console.log(`Tracking update - Allowed: ${allow}, ` +
        `Since last: ${timeSinceLast.toFixed(1)} min, ` +
        `Distance: ${distance.toFixed(1)}m, ` +
        `Accuracy: ${pt.accuracy || 'N/A'}m, ` +
        `Last: ${last ? `(${last.lat}, ${last.lng})` : 'none'}, ` +
        `New: (${pt.lat}, ${pt.lng})`);

      if (allow) {
        tx.update(ref, { pathMap: [...list, pt], lastUpdateAt: nowIso });
        accepted = true;
      } else {
        tx.update(ref, { lastUpdateAt: nowIso });
      }
    });

    return res.status(200).json({ ok: true, id, added: accepted ? pt : null, throttled: !accepted });
  } catch (e: any) {
    return res.status(400).json({ error: e?.message || String(e) });
  }
}

/** POST /api/tracking/check-out */
export async function trackingCheckOut(req: Request, res: Response) {
  try {
    const empid = pickEmpId(req);
    const dateIso = dateFromReq(req);
    const id = docId(empid, dateIso);
    const ref = db.collection(COL).doc(id);

    const now = new Date().toISOString();
    await ref.set({ endedAt: now, lastUpdateAt: now } as Partial<TrackDayDoc>, { merge: true });

    return res.status(200).json({ ok: true, id, endedAt: now });
  } catch (e: any) {
    return res.status(400).json({ error: e?.message || String(e) });
  }
}

/** GET /api/tracking/day?dateIso=YYYY-MM-DD */
export async function trackingGetDay(req: Request, res: Response) {
  try {
    const empid = pickEmpId(req);
    const dateIso = dateFromReq(req);
    const id = docId(empid, dateIso);

    const snap = await db.collection(COL).doc(id).get();
    if (!snap.exists) {
      const empty: TrackDayDoc = {
        id,
        empid,
        dateIso,
        pathMap: [],
        endedAt: null,
        lastUpdateAt: new Date().toISOString(),
      };
      return res.json({ ok: true, data: empty });
    }
    return res.json({ ok: true, data: snap.data() });
  } catch (e: any) {
    return res.status(400).json({ error: e?.message || String(e) });
  }
}
