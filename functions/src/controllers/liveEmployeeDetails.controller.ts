import { Request, Response } from 'express';
import { db } from '../config/firebase';
import { distanceMeters } from '../utils/geo';

type AttDoc = {
  empid: string;
  name?: string;
  date: string;                 // "YYYY-MM-DD"
  shift?: string;
  branchName?: string;
  checkIn?: string | null;
  checkOut?: string | null;
  checkInLatitude?: number | null;
  checkInLongitude?: number | null;
  expectedLatitude?: number | null;
  expectedLongitude?: number | null;
  expectedRadius?: number | null; // meters
  status?: string;
};

function pickDate(req: Request) {
  const q = (req.query.dateIso as string) || '';
  if (/^\d{4}-\d{2}-\d{2}$/.test(q)) return q;
  return new Date().toISOString().slice(0, 10);
}

export async function liveEmployeeDetails(req: Request, res: Response) {
  try {
    const empid =
      (req.params.empid || '').trim() ||
      String(req.headers['x-empid'] || '').trim();

    if (!empid) return res.status(400).json({ error: 'empid required' });

    const dateIso = pickDate(req);

    const snap = await db
      .collection('attendance')
      .where('empid', '==', empid)
      .where('date', '==', dateIso)
      .limit(1)
      .get();

    if (snap.empty) {
      return res.json({
        ok: true,
        data: {
          id: empid,
          name: '-',
          date: dateIso,
          shift: '-',
          location: '-',
          checkIn: null,
          checkOut: null,
          geofenceMeters: null,
          geofence: '-',
          latitude: null,
          longitude: null,
          expectedLatitude: null,
          expectedLongitude: null,
          status: 'Absent',
        },
      });
    }

    const d = snap.docs[0].data() as AttDoc;

    const lat = Number(d.checkInLatitude ?? NaN);
    const lng = Number(d.checkInLongitude ?? NaN);
    const expLat = Number(d.expectedLatitude ?? NaN);
    const expLng = Number(d.expectedLongitude ?? NaN);
    const radius = Number(d.expectedRadius ?? 0) || 0;

    let geoMeters: number | null = null;
    if (
      Number.isFinite(lat) &&
      Number.isFinite(lng) &&
      Number.isFinite(expLat) &&
      Number.isFinite(expLng)
    ) {
      geoMeters = Math.round(
        distanceMeters({ lat, lng }, { lat: expLat, lng: expLng }),
      );
    }

    const status =
      d.checkIn && `${d.checkIn}`.trim().isNotEmpty ? 'Present' : 'Absent';

    return res.json({
      ok: true,
      data: {
        id: d.empid,
        name: d.name ?? '-',
        date: d.date,
        shift: d.shift ?? '-',
        location: d.branchName ?? '-',
        checkIn: d.checkIn ?? null,
        checkOut: d.checkOut ?? null,
        geofenceMeters: geoMeters,
        geofence: radius ? `${radius} m` : '-',
        latitude: Number.isFinite(lat) ? lat : null,
        longitude: Number.isFinite(lng) ? lng : null,
        expectedLatitude: Number.isFinite(expLat) ? expLat : null,   // 👈 added
        expectedLongitude: Number.isFinite(expLng) ? expLng : null,  // 👈 added
        status,
      },
    });
  } catch (e: any) {
    return res.status(500).json({ error: e?.message || String(e) });
  }
}

// tiny guard for TS
declare global {
  interface String {
    isNotEmpty: boolean;
  }
}
Object.defineProperty(String.prototype, 'isNotEmpty', {
  get() {
    return (this as string).trim().length > 0;
  },
});
