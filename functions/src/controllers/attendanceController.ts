// import { Request, Response } from 'express';
// import * as admin from 'firebase-admin';

// const db = admin.firestore();

// /* ============================== Helpers ============================== */

// const EMP_COL       = 'employees';
// const ATT_COL       = 'attendance';
// const LEAVE_COL     = 'leaves';
// const SHIFT_COL     = 'shifts';
// const OFFICE_COL    = 'officeLocations';
// const OTHER_LOC_COL = 'otherLocation'; // separate collection for other-location events

// function pad2(n: number | string) { return String(n).padStart(2, '0'); }

// // --- Time helpers (IST + UTC) ---
// // Use Intl with Asia/Kolkata instead of adding 5.5h manually.
// const IST_TZ = 'Asia/Kolkata';

// function toYMD(d: Date = new Date()): string {
//   const fmt = new Intl.DateTimeFormat('en-CA', {
//     timeZone: IST_TZ,
//     year: 'numeric',
//     month: '2-digit',
//     day: '2-digit',
//   });
//   return fmt.format(d); // YYYY-MM-DD
// }

// function nowTimeIST(): string {
//   const parts = new Intl.DateTimeFormat('en-GB', {
//     timeZone: IST_TZ,
//     hour: '2-digit',
//     minute: '2-digit',
//     second: '2-digit',
//     hour12: false,
//   })
//     .formatToParts(new Date())
//     .reduce<Record<string, string>>((acc, p) => {
//       if (p.type !== 'literal') acc[p.type] = p.value;
//       return acc;
//     }, {});
//   return `${parts.hour}:${parts.minute}:${parts.second}`; // HH:mm:ss
// }

// function nowUtcISO(): string {
//   return new Date().toISOString(); // exact instant (UTC) for audits
// }

// function daysInMonth(year: number, month: number) { return new Date(year, month, 0).getDate(); }

// /* ====== CHANGED: timezone-safe weekday detection for YYYY-MM-DD ======
//    Avoid new Date('YYYY-MM-DD') which is parsed as UTC in Node.
//    dayOfWeekFromYMD returns: 0=Sunday, 1=Monday, ..., 6=Saturday
// */
// function dayOfWeekFromYMD(ymd: string): number {
//   const y = parseInt(ymd.slice(0, 4), 10);
//   const m = parseInt(ymd.slice(5, 7), 10);
//   const d = parseInt(ymd.slice(8, 10), 10);
//   let Y = y, M = m;
//   if (M < 3) { M += 12; Y -= 1; }
//   const K = Y % 100;
//   const J = Math.floor(Y / 100);
//   // Zeller’s congruence (Gregorian):
//   // h = 0..6 => 0=Saturday,1=Sunday,2=Monday,...,6=Friday
//   const h = (d + Math.floor((13 * (M + 1)) / 5) + K + Math.floor(K / 4) + Math.floor(J / 4) + 5 * J) % 7;
//   // Convert to 0=Sunday..6=Saturday
//   return (h + 6) % 7;
// }
// function isSunday(ymd: string) { return dayOfWeekFromYMD(ymd) === 0; } // <— callers unchanged

// function cmpHHMM(a?: string, b?: string) { return (a || '00:00') > (b || '00:00'); }

// function midpointHHMM(start?: string, end?: string) {
//   const [h1, m1] = (start || '00:00').split(':').map(Number);
//   const [h2, m2] = (end   || '23:59').split(':').map(Number);
//   const s1 = h1 * 3600 + m1 * 60, s2 = h2 * 3600 + m2 * 60;
//   const mid = Math.floor((s1 + s2) / 2);
//   const mh = Math.floor(mid / 3600), mm = Math.floor((mid % 3600) / 60);
//   return `${pad2(mh)}:${pad2(mm)}`;
// }

// function toISO(v: any): string {
//   try {
//     if (!v) return '';
//     if (typeof v === 'string') return v.slice(0, 10);
//     if (v.toDate && typeof v.toDate === 'function') return v.toDate().toISOString().slice(0, 10);
//     const d = new Date(v);
//     return d.toISOString().slice(0, 10);
//   } catch { return ''; }
// }
// function eachYMD(start: string, end: string) {
//   const out: string[] = [];
//   const d = new Date(start);
//   for (;;) {
//     const ymd = d.toISOString().slice(0, 10);
//     out.push(ymd);
//     if (ymd === end) break;
//     d.setDate(d.getDate() + 1);
//   }
//   return out;
// }

// // project-level holiday set (optional)
// const HOLIDAYS_SET = new Set<string>([]);

// /* ==== tolerant helpers for emp id ==== */
// const pickEmpId = (obj: any): string | null => {
//   const v = obj?.empid ?? obj?.empId ?? obj?.employeeId ?? null;
//   return v ? String(v).trim() : null;
// };
// const getReqEmpId = (req: Request): string | null => {
//   return pickEmpId((req as any).body) || pickEmpId((req as any).user) || null;
// };

// const normStr = (s: any) => String(s ?? '').trim();
// const lower = (s: string) => s.trim().toLowerCase();

// /* ============ GEO helpers ============ */

// // Haversine distance in meters
// function haversineMeters(lat1?: number|null, lon1?: number|null, lat2?: number|null, lon2?: number|null) {
//   if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;
//   const R = 6371000; // meters
//   const toRad = (x: number) => (x * Math.PI) / 180;
//   const dLat = toRad(lat2 - lat1);
//   const dLon = toRad(lon2 - lon1);
//   const a =
//     Math.sin(dLat/2) * Math.sin(dLat/2) +
//     Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
//     Math.sin(dLon/2) * Math.sin(dLon/2);
//   const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
//   return Math.round(R * c);
// }

// // find office by branch name (case-insensitive fallback)
// async function findOfficeByBranchName(branchNameRaw: string) {
//   const branchName = normStr(branchNameRaw);
//   if (!branchName) return null;

//   // Try exact match on branchName
//   const exact = await db.collection(OFFICE_COL).where('branchName', '==', branchName).limit(1).get();
//   if (!exact.empty) {
//     const d = exact.docs[0];
//     return { id: d.id, ...d.data() } as any;
//   }

//   // Fallback: load a small page & do case-insensitive compare
//   const snap = await db.collection(OFFICE_COL).limit(50).get();
//   for (const d of snap.docs) {
//     const data = d.data() as any;
//     const bn = normStr(data.branchName || data.name || '');
//     if (lower(bn) === lower(branchName)) {
//       return { id: d.id, ...data };
//     }
//   }
//   return null;
// }

// /* ============================== NEW: Other Location capture ============================== */

// type OtherLocEventType = 'check-in' | 'check-out';

// async function createOtherLocationEvent(params: {
//   empid: string;
//   name: string;
//   date: string;
//   time: string;
//   type: OtherLocEventType;
//   branchName: string | null;

//   // device coords at event time
//   latitude: number | null;
//   longitude: number | null;
//   accuracy?: number | null;

//   // expected (branch) snapshot
//   expectedLatitude: number | null;
//   expectedLongitude: number | null;
//   expectedRadius: number | null;

//   // computed deltas
//   distanceFromBranch: number | null;
//   withinRadius: boolean | null;

//   // text reason
//   otherLocation: string | null;
// }) {
//   const payload = {
//     source: 'attendance' as const,
//     approvalStatus: 'Pending',
//     createdAt: admin.firestore.FieldValue.serverTimestamp(),
//     updatedAt: admin.firestore.FieldValue.serverTimestamp(),

//     empid: params.empid,
//     name: params.name,
//     date: params.date,
//     time: params.time,
//     type: params.type,
//     branchName: params.branchName,

//     // device
//     latitude: params.latitude,
//     longitude: params.longitude,
//     accuracy: params.accuracy ?? null,

//     // expected snapshot
//     expectedLatitude: params.expectedLatitude,
//     expectedLongitude: params.expectedLongitude,
//     expectedRadius: params.expectedRadius,

//     // deltas
//     distanceFromBranch: params.distanceFromBranch,
//     withinRadius: params.withinRadius,

//     otherLocation: params.otherLocation,
//   };
//   await db.collection(OTHER_LOC_COL).add(payload as any);
// }

// /* ============================== Core attendance (string-time model) ============================== */

// /** Get current user (from req.user) */
// export const getCurrentUser = async (req: Request, res: Response) => {
//   try {
//     const empid = getReqEmpId(req);
//     const snap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
//     if (snap.empty) return res.status(404).json({ error: 'Employee not found' });
//     const d = snap.docs[0].data();
//     return res.json({
//       empid: d.empid,
//       name:  d.name,
//       role:  (req as any).user?.role,
//       shiftGroup: d.shiftGroup,
//     });
//   } catch (err: any) {
//     console.error('getCurrentUser error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** POST /api/attendance/check-in */
// export const checkIn = async (req: Request, res: Response) => {
//   const empid    = getReqEmpId(req) || '';
//   const name     = normStr((req.body as any)?.name);
//   const location = normStr((req.body as any)?.location); // should be branch name

//   // coordinates from app
//   const checkInLatitude  = typeof (req.body as any)?.latitude  === 'number' ? (req.body as any).latitude  : null;
//   const checkInLongitude = typeof (req.body as any)?.longitude === 'number' ? (req.body as any).longitude : null;
//   const checkInAccuracy  = typeof (req.body as any)?.accuracy  === 'number' ? (req.body as any).accuracy  : null;
//   const checkInSource    = normStr((req.body as any)?.source) || null; // manual/biometric

//   // ===== NEW: Reason coming from client (dropdown) =====
//   const reasonId        = normStr((req.body as any)?.reasonId) || null;
//   const reasonText      = normStr((req.body as any)?.reasonText || (req.body as any)?.reason) || null;
//   const reasonTypeId    = normStr((req.body as any)?.reasonTypeId) || null;
//   const reasonTypeName  = normStr((req.body as any)?.reasonTypeName) || null;

//   if (!empid || !name || !location) {
//     return res.status(400).json({ error: 'empid, name and location are required' });
//   }
//   const today = toYMD(new Date());

//   try {
//     // 1) find/create today's doc
//     const snap = await db.collection(ATT_COL)
//       .where('empid', '==', empid)
//       .where('date', '==', today)
//       .limit(1)
//       .get();

//     const nowTime = nowTimeIST(); // HH:mm:ss (IST)

//     // 2) figure out branch to compare against (prefer request, fallback employee.profile)
//     let branchName = location;
//     const empSnap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
//     const empRow = empSnap.empty ? null : empSnap.docs[0].data();
//     if (!branchName && (empRow as any)?.location) branchName = normStr((empRow as any).location);

//     // 3) find office & compute distance
//     let expectedLatitude: number | null = null;
//     let expectedLongitude: number | null = null;
//     let expectedRadius: number | null = null;
//     let distanceFromBranch: number | null = null;
//     let withinRadius: boolean | null = null;
//     let otherLocation: string | null = null;

//     const office = await findOfficeByBranchName(branchName);
//     if (office) {
//       expectedLatitude  = Number((office as any).latitude ?? 0) || 0;
//       expectedLongitude = Number((office as any).longitude ?? 0) || 0;
//       expectedRadius    = Number((office as any).radius ?? 0) || 0;

//       distanceFromBranch = haversineMeters(
//         checkInLatitude, checkInLongitude, expectedLatitude, expectedLongitude
//       );

//       if (distanceFromBranch != null && expectedRadius != null) {
//         withinRadius = distanceFromBranch <= expectedRadius;
//         if (!withinRadius) {
//           otherLocation = `Outside radius by ${Math.max(0, distanceFromBranch - expectedRadius)} m`;
//         }
//       }
//     } else {
//       // branch not configured
//       otherLocation = 'No matching branch in officeLocations';
//     }

//     // 4) write attendance record + capture other-location event when needed
//     if (!snap.empty) {
//       const doc = snap.docs[0];
//       const data = doc.data();

//       if (data.checkIn) {
//         // still push/update reason if provided (no harm)
//         if (reasonText) {
//           await doc.ref.set({
//             reason: reasonText,
//             reasonId: reasonId || null,
//             reasonTypeId: reasonTypeId || null,
//             reasonTypeName: reasonTypeName || null,
//             updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//           }, { merge: true });
//         }

//         if (!empSnap.empty) {
//           await empSnap.docs[0].ref.set(
//             { status: 'active', updatedAt: admin.firestore.FieldValue.serverTimestamp() },
//             { merge: true }
//           );
//         }
//         if (withinRadius === false || (otherLocation && otherLocation.trim() !== '')) {
//           await createOtherLocationEvent({
//             empid, name, date: today, time: nowTime, type: 'check-in',
//             branchName,
//             latitude: checkInLatitude, longitude: checkInLongitude, accuracy: checkInAccuracy,
//             expectedLatitude, expectedLongitude, expectedRadius,
//             distanceFromBranch, withinRadius, otherLocation
//           });
//         }
//         return res.status(200).json({
//           message: 'Already checked in today',
//           code: 'ALREADY_CHECKED_IN',
//           attendanceId: doc.id,
//           record: { id: doc.id, ...data },
//         });
//       }

//       await doc.ref.update({
//         checkIn: nowTime,
//         checkInTsUtc: nowUtcISO(),              // <<< AUDIT FIELD
//         name,
//         location: branchName,
//         checkInLatitude,
//         checkInLongitude,
//         checkInAccuracy,
//         checkInSource,
//         branchName: branchName || null,
//         expectedLatitude,
//         expectedLongitude,
//         expectedRadius,
//         distanceFromBranch,
//         withinRadius,
//         otherLocation,
//         // ===== NEW: persist reason to attendance =====
//         ...(reasonText ? { reason: reasonText } : {}),
//         ...(reasonId ? { reasonId } : {}),
//         ...(reasonTypeId ? { reasonTypeId } : {}),
//         ...(reasonTypeName ? { reasonTypeName } : {}),
//         status: 'Present',
//         approvalStatus: 'Pending',
//         updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//       });

//       if (withinRadius === false || (otherLocation && otherLocation.trim() !== '')) {
//         await createOtherLocationEvent({
//           empid, name, date: today, time: nowTime, type: 'check-in',
//           branchName,
//           latitude: checkInLatitude, longitude: checkInLongitude, accuracy: checkInAccuracy,
//           expectedLatitude, expectedLongitude, expectedRadius,
//           distanceFromBranch, withinRadius, otherLocation
//         });
//       }

//       if (!empSnap.empty) {
//         await empSnap.docs[0].ref.update({
//           status: 'active',
//           updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//         });
//       }
//       return res.json({ message: 'Check-in updated' });
//     }

//     // new record
//     await db.collection(ATT_COL).add({
//       empid,
//       name,
//       date: today,
//       checkIn: nowTime,
//       checkInTsUtc: nowUtcISO(),                // <<< AUDIT FIELD
//       location: branchName,
//       checkInLatitude,
//       checkInLongitude,
//       checkInAccuracy,
//       checkInSource,
//       branchName: branchName || null,
//       expectedLatitude,
//       expectedLongitude,
//       expectedRadius,
//       distanceFromBranch,
//       withinRadius,
//       otherLocation,
//       // ===== NEW: persist reason to attendance =====
//       ...(reasonText ? { reason: reasonText } : {}),
//       ...(reasonId ? { reasonId } : {}),
//       ...(reasonTypeId ? { reasonTypeId } : {}),
//       ...(reasonTypeName ? { reasonTypeName } : {}),
//       status: 'Present',
//       approvalStatus: 'Pending',
//       createdAt: admin.firestore.FieldValue.serverTimestamp(),
//       updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//     });

//     if (withinRadius === false || (otherLocation && otherLocation.trim() !== '')) {
//       await createOtherLocationEvent({
//         empid, name, date: today, time: nowTime, type: 'check-in',
//         branchName,
//         latitude: checkInLatitude, longitude: checkInLongitude, accuracy: checkInAccuracy,
//         expectedLatitude, expectedLongitude, expectedRadius,
//         distanceFromBranch, withinRadius, otherLocation
//       });
//     }

//     const empSnap2 = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
//     if (!empSnap2.empty) {
//       await empSnap2.docs[0].ref.update({
//         status: 'active',
//         updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//       });
//     }

//     return res.json({ message: 'Checked-in successfully' });
//   } catch (err: any) {
//     console.error('checkIn error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** POST /api/attendance/check-out */
// export const checkOut = async (req: Request, res: Response) => {
//   const empid    = getReqEmpId(req) || '';
//   const location = normStr((req.body as any)?.location);

//   const checkOutLatitude  = typeof (req.body as any)?.latitude  === 'number' ? (req.body as any).latitude  : null;
//   const checkOutLongitude = typeof (req.body as any)?.longitude === 'number' ? (req.body as any).longitude : null;
//   const checkOutAccuracy  = typeof (req.body as any)?.accuracy  === 'number' ? (req.body as any).accuracy  : null;

//   // ===== NEW: Reason coming from client (dropdown) for checkout as well =====
//   const reasonId        = normStr((req.body as any)?.reasonId) || null;
//   const reasonText      = normStr((req.body as any)?.reasonText || (req.body as any)?.reason) || null;
//   const reasonTypeId    = normStr((req.body as any)?.reasonTypeId) || null;
//   const reasonTypeName  = normStr((req.body as any)?.reasonTypeName) || null;

//   if (!empid || !location) {
//     return res.status(400).json({ error: 'empid and location are required' });
//   }
//   const today = toYMD(new Date());

//   try {
//     const snap = await db.collection(ATT_COL)
//       .where('empid', '==', empid)
//       .where('date', '==', today)
//       .limit(1)
//       .get();

//     if (snap.empty) return res.status(400).json({ error: 'You need to check in first' });

//     const doc = snap.docs[0];
//     if (doc.data().checkOut) {
//       // still allow saving/overriding reason if sent
//       if (reasonText) {
//         await doc.ref.set({
//           reason: reasonText,
//           reasonId: reasonId || null,
//           reasonTypeId: reasonTypeId || null,
//           reasonTypeName: reasonTypeName || null,
//           updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//         }, { merge: true });
//       }
//       return res.status(400).json({ error: 'Already checked out today' });
//     }

//     const current = doc.data() as any;
//     const branchName = normStr(current.branchName || location || current.location || '');

//     let expectedLatitude: number | null = current.expectedLatitude ?? null;
//     let expectedLongitude: number | null = current.expectedLongitude ?? null;
//     let expectedRadius: number | null = current.expectedRadius ?? null;

//     if (expectedLatitude == null || expectedLongitude == null || expectedRadius == null) {
//       const office = await findOfficeByBranchName(branchName);
//       if (office) {
//         expectedLatitude  = Number((office as any).latitude ?? 0) || 0;
//         expectedLongitude = Number((office as any).longitude ?? 0) || 0;
//         expectedRadius    = Number((office as any).radius ?? 0) || 0;
//       }
//     }

//     const checkoutDistanceFromBranch = haversineMeters(checkOutLatitude, checkOutLongitude, expectedLatitude, expectedLongitude);
//     const checkoutWithinRadius = (checkoutDistanceFromBranch != null && expectedRadius != null)
//       ? checkoutDistanceFromBranch <= expectedRadius
//       : null;

//     const nowTime = nowTimeIST();

//     await doc.ref.update({
//       checkOut: nowTime,
//       checkOutTsUtc: nowUtcISO(),               // <<< AUDIT FIELD
//       location: branchName,
//       checkOutLatitude,
//       checkOutLongitude,
//       checkOutAccuracy,
//       branchName,
//       expectedLatitude,
//       expectedLongitude,
//       expectedRadius,
//       checkoutDistanceFromBranch,
//       checkoutWithinRadius,
//       // ===== NEW: persist reason to attendance on checkout as well =====
//       ...(reasonText ? { reason: reasonText } : {}),
//       ...(reasonId ? { reasonId } : {}),
//       ...(reasonTypeId ? { reasonTypeId } : {}),
//       ...(reasonTypeName ? { reasonTypeName } : {}),
//       updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//     });

//     if (checkoutWithinRadius === false) {
//       await createOtherLocationEvent({
//         empid,
//         name: normStr(current.name || ''),
//         date: today,
//         time: nowTime,
//         type: 'check-out',
//         branchName,
//         latitude: checkOutLatitude,
//         longitude: checkOutLongitude,
//         accuracy: checkOutAccuracy,
//         expectedLatitude,
//         expectedLongitude,
//         expectedRadius,
//         distanceFromBranch: checkoutDistanceFromBranch,
//         withinRadius: checkoutWithinRadius,
//         otherLocation: `Outside radius by ${Math.max(0, (checkoutDistanceFromBranch ?? 0) - (expectedRadius ?? 0))} m`,
//       });
//     }

//     const empSnap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
//     if (!empSnap.empty) {
//       await empSnap.docs[0].ref.update({
//         status: 'inactive',
//         updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//       });
//     }

//     return res.json({ message: 'Checked-out & set inactive' });
//   } catch (err: any) {
//     console.error('checkOut error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** GET /api/attendance/live */
// export const getLiveAttendance = async (req: Request, res: Response) => {
//   const today = toYMD(new Date());
//   const isAdmin = (req as any).user?.role === 'admin';

//   try {
//     let employees: any[] = [];
//     if (isAdmin) {
//       const empSnap = await db.collection(EMP_COL).get();
//       employees = empSnap.docs.map(d => d.data());
//     } else {
//       const empid = getReqEmpId(req);
//       const empSnap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
//       if (empSnap.empty) return res.json([]);
//       employees = [empSnap.docs[0].data()];
//     }

//     const attSnap = await db.collection(ATT_COL).where('date', '==', today).get();
//     const attMap: Record<string, any> = Object.fromEntries(attSnap.docs.map(d => [d.data().empid, d.data()]));

//     const leaveSnap = await db.collection(LEAVE_COL)
//       .where('approvalStatus', '==', 'Approved')
//       .where('startDate', '<=', today)
//       .get();
//     const validLeaves = leaveSnap.docs
//       .map(d => d.data())
//       .filter(l => (toISO((l as any).endDate) || toISO((l as any).startDate)) >= today)
//       .map(l => (l as any).empid);
//     const leaveSet = new Set(validLeaves);

//     const shiftsSnap = await db.collection(SHIFT_COL).get();
//     const shiftByGroup: Record<string, any> =
//       Object.fromEntries(shiftsSnap.docs.map(d => [d.data().group, d.data()]));

//     const isHoliday = HOLIDAYS_SET.has(today);
//     const isWeekOff = isSunday(today); // <— now IST-safe

//     const result = employees.map(emp => {
//       const rec = attMap[(emp as any).empid];
//       let status: string;
//       let isLate = false, isEarly = false;

//       let permissionCount = Array.isArray(rec?.permissionRequests)
//         ? rec.permissionRequests.length
//         : (rec?.permissionRequest ? 1 : 0);

//       if (isHoliday) status = 'Holiday';
//       else if (isWeekOff) status = 'WeekOff';
//       else if (leaveSet.has((emp as any).empid)) status = 'Leave';
//       else if (rec?.checkIn) {
//         status = 'Present';
//         const shift = shiftByGroup[(emp as any).shiftGroup] || {};
//         const start = shift.startTime || '09:00';
//         const end   = shift.endTime   || '18:00';
//         isLate  = rec.checkIn  > start;
//         isEarly = rec.checkOut && rec.checkOut < end;
//       } else {
//         status = 'Absent';
//       }

//       let isHalfDay = false;
//       if (status === 'Present' && shiftByGroup[(emp as any).shiftGroup]) {
//         const [h1, m1] = (shiftByGroup[(emp as any).shiftGroup].startTime || '09:00').split(':').map(Number);
//         const [h2, m2] = (shiftByGroup[(emp as any).shiftGroup].endTime   || '18:00').split(':').map(Number);
//         const midSec = ((h1 * 3600 + m1 * 60) + (h2 * 3600 + m2 * 60)) / 2;
//         const inSec = rec && rec.checkIn
//           ? rec.checkIn.split(':').reduce((a: number, v: string, i: number) => a + (+v) * (i === 0 ? 3600 : 60), 0)
//           : 0;
//         isHalfDay = inSec > midSec;
//       }

//       return {
//         empid:          (emp as any).empid,
//         name:           (emp as any).name,
//         shiftGroup:     (emp as any).shiftGroup,
//         date:           today,
//         status,
//         checkIn:        rec?.checkIn || null,
//         checkOut:       rec?.checkOut || null,
//         late:           isLate,
//         early:          isEarly,
//         permissionCount,
//         leave:          status === 'Leave',
//         holiday:        status === 'Holiday',
//         weekOff:        status === 'WeekOff',
//         halfDay:        isHalfDay,
//         branchName:                 rec?.branchName ?? null,
//         withinRadius:               rec?.withinRadius ?? null,
//         distanceFromBranch:         rec?.distanceFromBranch ?? null,
//         checkoutWithinRadius:       rec?.checkoutWithinRadius ?? null,
//         checkoutDistanceFromBranch: rec?.checkoutDistanceFromBranch ?? null,
//       };
//     });

//     return res.json(result);
//   } catch (err: any) {
//     console.error('getLiveAttendance error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** GET /api/attendance/employee/:empid */
// export const getEmployeeAttendance = async (req: Request, res: Response) => {
//   const { empid } = req.params;
//   try {
//     const snap = await db.collection(ATT_COL)
//       .where('empid', '==', empid)
//       .orderBy('date', 'desc').get();
//     const records = snap.docs.map(d => ({ id: d.id, ...d.data() }));
//     return res.json(records);
//   } catch (err: any) {
//     console.error('getEmployeeAttendance error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** Admin: list all attendance records */
// export const getAllAttendance = async (_req: Request, res: Response) => {
//   try {
//     const snap = await db.collection(ATT_COL).get();
//     const records = snap.docs.map(d => ({ id: d.id, ...d.data() }));
//     return res.json(records);
//   } catch (err: any) {
//     console.error('getAllAttendance error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** Admin: approve/reject an attendance row by document id */
// export const approveAttendance = async (req: Request, res: Response) => {
//   const { id, status } = req.body as { id: string; status: 'Approved' | 'Rejected' | string };
//   try {
//     await db.collection(ATT_COL).doc(id).update({
//       approvalStatus: status,
//       updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//     });
//     return res.json({ message: `Attendance ${String(status).toLowerCase()} successfully` });
//   } catch (err: any) {
//     console.error('approveAttendance error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** GET /api/attendance/monthly/:empid/:year/:month */
// export const getMonthlySummary = async (req: Request, res: Response) => {
//   const { empid, year, month } = req.params as any;
//   try {
//     const snap = await db.collection(ATT_COL)
//       .where('empid', '==', empid)
//       .where('date', '>=', `${year}-${month}-01`)
//       .where('date', '<=', `${year}-${month}-31`)
//       .get();
//     const records = snap.docs.map(d => ({ id: d.id, ...d.data() }));
//     return res.json(records);
//   } catch (err: any) {
//     console.error('getMonthlySummary error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** GET /api/attendance/roster?date=YYYY-MM-DD */
// export const getDailyRoster = async (req: Request, res: Response) => {
//   const date = String(req.query.date || '');
//   if (!date) return res.status(400).json({ error: 'Missing ?date=YYYY-MM-DD' });

//   try {
//     const empSnap = await db.collection(EMP_COL).get();
//     const employees = empSnap.docs.map(d => d.data());

//     const attSnap = await db.collection(ATT_COL).where('date', '==', date).get();
//     const attByEmp: Record<string, any> = Object.fromEntries(attSnap.docs.map(d => [d.data().empid, d.data()]));

//     const roster = employees.map((emp: any) => {
//       const rec = attByEmp[emp.empid];
//       let raw = 'Absent';
//       if (rec?.approvalStatus === 'Approved' && !rec.checkIn) raw = 'Leave';
//       else if (rec?.checkIn) raw = rec.checkIn > '09:00' ? 'Late' : 'Present';
//       return {
//         empid:      emp.empid,
//         name:       emp.name || '',
//         shiftGroup: emp.shiftGroup,
//         status:     (raw === 'Present' || raw === 'Late') ? 'active' : 'inactive',
//       };
//     });

//     return res.json(roster);
//   } catch (err: any) {
//     console.error('getDailyRoster error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** GET /api/attendance/range-summary?start=YYYY-MM-DD&end=YYYY-MM-DD */
// export const getRangeSummary = async (req: Request, res: Response) => {
//   try {
//     const start = String(req.query.start || '').slice(0, 10);
//     const end   = String(req.query.end   || '').slice(0, 10);
//     if (!start || !end || new Date(end) < new Date(start)) {
//       return res.status(400).json({ error: 'Provide ?start=YYYY-MM-DD&end=YYYY-MM-DD' });
//     }

//     const empSnap = await db.collection(EMP_COL).get();
//     const employees = empSnap.docs.map(d => d.data());

//     const activeEmployees = employees.filter((e: any) =>
//       String(e.status || '').toLowerCase() === 'active'
//     ).length;

//     const shiftsSnap = await db.collection(SHIFT_COL).get();
//     const shiftByGroup: Record<string, any> =
//       Object.fromEntries(shiftsSnap.docs.map(d => [d.data().group, d.data()]));

//     const attSnap = await db.collection(ATT_COL)
//       .where('date', '>=', start).where('date', '<=', end).get();
//     const attByEmpDate: Record<string, any> = {};
//     attSnap.forEach(doc => { const a = doc.data(); attByEmpDate[`${(a as any).empid}|${(a as any).date}`] = { id: doc.id, ...a }; });

//     const leavesSnap = await db.collection(LEAVE_COL).get();
//     const approvedLeaves = leavesSnap.docs
//       .map(d => d.data())
//       .filter((L: any) => String(L.approvalStatus ?? L.status ?? 'Pending').toLowerCase() === 'approved')
//       .map((L: any) => ({
//         empid: L.empid,
//         type: String(L.type || ''),
//         start: toISO(L.startDate || L.selectDate || L.date),
//         end:   toISO(L.endDate   || L.selectDate || L.date || L.startDate),
//       }));

//     const leaveDays = new Set<string>();
//     let onLeaveCount = 0;
//     for (const L of approvedLeaves) {
//       if (!L.start) continue;
//       const s = L.start, e = L.end || L.start;
//       if (e < start || s > end) continue;
//       for (const d of eachYMD((s < start ? start : s), (e > end ? end : e))) {
//         leaveDays.add(`${L.empid}|${d}`); onLeaveCount++;
//       }
//     }

//     let checkedIn = 0, absent = 0, lateIn = 0, earlyOut = 0, halfDay = 0, presentApproved = 0, holiday = 0, weekOff = 0;
//     const rows: any[] = [];
//     const dates = eachYMD(start, end);

//     for (const ymd of dates) {
//       const isHoliday = HOLIDAYS_SET.has(ymd);
//       const isWO = isSunday(ymd); // <— now IST-safe
//       if (isHoliday) holiday++;
//       if (isWO) weekOff++;

//       for (const emp of employees) {
//         const key   = `${(emp as any).empid}|${ymd}`;
//         const att   = attByEmpDate[key] || null;
//         const shift = shiftByGroup[(emp as any).shiftGroup] || { startTime: '09:00', endTime: '18:00' };
//         const startT = shift.startTime || '09:00';
//         const endT   = shift.endTime   || '18:00';
//         const mid    = midpointHHMM(startT, endT);

//         let status = 'Absent';
//         let isLate = false, isEarly = false;

//         if (isHoliday) {
//           status = 'Holiday';
//         } else if (isWO) {
//           status = 'WeekOff';
//         } else if (leaveDays.has(key)) {
//           status = approvedLeaves.find(l =>
//             (l as any).empid === (emp as any).empid && (l as any).start <= ymd && ymd <= ((l as any).end || (l as any).start) && (l as any).type.toLowerCase().includes('half')
//           ) ? 'Half Day' : 'On Leave';
//           if (status === 'Half Day') halfDay++;
//         } else if (att?.checkIn) {
//           checkedIn++;
//           status = 'Present';
//           if (cmpHHMM(att.checkIn as any, startT)) { isLate = true; lateIn++; }
//           if ((att as any).checkOut && !cmpHHMM((att as any).checkOut, endT)) { isEarly = true; earlyOut++; }
//           if (cmpHHMM(att.checkIn as any, mid)) { status = 'Half Day'; halfDay++; }
//           if (String((att as any).approvalStatus || '').toLowerCase() === 'approved') presentApproved++;
//         } else {
//           absent++;
//         }

//         rows.push({
//           employeeId:  (emp as any).empid,
//           employeeName: (emp as any).name || '',
//           shift:       (emp as any).shift || (emp as any).shiftGroup || '',
//           date:        ymd,
//           checkIn:     (att as any)?.checkIn || '-',
//           checkOut:    (att as any)?.checkOut || '-',
//           department:  (emp as any).dept || (emp as any).department || '',
//           attendance:  status,
//           workedHours: (att as any)?.workedHours ? String((att as any).workedHours) : '-',
//           late:        isLate,
//           early:       isEarly,
//           approval:    (att as any)?.approvalStatus || 'Pending',
//         });
//       }
//     }

//     return res.json({
//       counts: {
//         activeEmployees,
//         onLeave: onLeaveCount,
//         checkedIn,
//         absent,
//         lateCheckIn: lateIn,
//         earlyCheckOut: earlyOut,
//         halfDay,
//         present: presentApproved,
//         holiday,
//         weekOff,
//       },
//       rows,
//     });
//   } catch (err: any) {
//     console.error('getRangeSummary error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** GET /api/attendance/month-view/:empid/:year/:month */
// export const getMonthView = async (req: Request, res: Response) => {
//   try {
//     const { empid, year, month } = req.params as any;
//     const y = parseInt(year, 10);
//     const m = parseInt(month, 10);
//     if (!empid || !y || !m) return res.status(400).json({ error: 'Bad params' });

//     const first = `${year}-${month}-01`;
//     const last  = `${year}-${month}-${pad2(daysInMonth(y, m))}`;

//     const empSnap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
//     if (empSnap.empty) return res.status(404).json({ error: 'Employee not found' });
//     const emp = empSnap.docs[0].data();

//     const shiftSnap = await db.collection(SHIFT_COL).where('group', '==', (emp as any).shiftGroup).limit(1).get();
//     const shift = shiftSnap.empty ? {} : shiftSnap.docs[0].data();
//     const shiftStart = (shift as any).startTime || '09:00';
//     const shiftEnd   = (shift as any).endTime   || '18:00';
//     const mid        = midpointHHMM(shiftStart, shiftEnd);

//     const attSnap = await db.collection(ATT_COL)
//       .where('empid', '==', empid)
//       .where('date', '>=', first)
//       .where('date', '<=', last)
//       .get();
//     const attByDate: Record<string, any> = Object.fromEntries(attSnap.docs.map(d => [d.data().date, d.data()]));

//     const leavesSnap = await db.collection(LEAVE_COL).where('empid', '==', empid).get();

//     const rangeLeaves: Array<{ start: string; end: string; isHalf: boolean }> = [];
//     let permissionCount = 0;

//     leavesSnap.forEach(doc => {
//       const l = doc.data();
//       const type = String((l as any).type || '').toLowerCase();
//       const sdStr = toISO((l as any).startDate || (l as any).selectDate || (l as any).date);
//       const edStr = toISO((l as any).endDate   || (l as any).selectDate || (l as any).date || (l as any).startDate);

//       if (type.includes('permission')) {
//         if ((sdStr && sdStr >= first && sdStr <= last) ||
//             (edStr && edStr >= first && edStr <= last)) {
//           permissionCount += 1;
//         }
//         return;
//       }
//       if (!sdStr) return;

//       const start = sdStr;
//       const end   = edStr || sdStr;
//       if (end < first || start > last) return;

//       rangeLeaves.push({ start, end, isHalf: type.includes('half') });
//     });

//     const holidaySet = new Set<string>(HOLIDAYS_SET);

//     const dayStatuses: Record<string, string> = {};
//     let present = 0, absent = 0, leave = 0, holiday = 0, weekOff = 0, halfDay = 0, late = 0, early = 0;

//     const today = toYMD(new Date());
//     const stopAt = (year === today.slice(0, 4) && month === today.slice(5, 7)) ? today : last;

//     for (let d = 1; d <= daysInMonth(y, m); d++) {
//       const ymd = `${year}-${month}-${pad2(d)}`;
//       if (ymd > stopAt) continue;

//       let status: string;

//       if (holidaySet.has(ymd)) {
//         status = 'Holiday'; holiday++;
//       } else if (isSunday(ymd)) { // <— now IST-safe
//         status = 'WeekOff'; weekOff++;
//       } else {
//         const lv = rangeLeaves.find(L => (L as any).start <= ymd && ymd <= (L as any).end);
//         if (lv) {
//           if ((lv as any).isHalf) { status = 'HalfDay'; halfDay++; }
//           else                   { status = 'Leave';   leave++;   }
//         } else {
//           const rec = attByDate[ymd];
//           if (rec && (rec as any).checkIn) {
//             status = 'Present'; present++;
//             if (cmpHHMM((rec as any).checkIn, shiftStart)) late++;
//             if ((rec as any).checkOut && !cmpHHMM((rec as any).checkOut, shiftEnd)) early++;
//             if (cmpHHMM((rec as any).checkIn, mid)) {
//               status = 'HalfDay';
//               halfDay++;
//               present--;
//             }
//           } else {
//             status = 'Absent'; absent++;
//           }
//         }
//       }

//       dayStatuses[ymd] = status;
//     }

//     return res.json({
//       empid,
//       month: `${year}-${month}`,
//       shift: { group: (emp as any).shiftGroup, startTime: shiftStart, endTime: shiftEnd, midpoint: mid },
//       dayStatuses,
//       totals: { present, absent, leave, holiday, weekOff, halfDay },
//       extras: { lateCheckin: late, earlyCheckout: early, permissionCount },
//     });
//   } catch (err: any) {
//     console.error('getMonthView error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /* ============================== Approvals & My Requests ============================== */

// const normalizeType = (s: any) => {
//   const t = normStr(s).toLowerCase().replace(/\s+/g, ' ');
//   if (!t || t === 'all' || t === 'type') return 'all';
//   if (t.includes('other') && t.includes('location')) return 'attendance:other_location'; // NEW
//   if (t.includes('late')  && t.includes('check') && t.includes('in'))  return 'late check in';
//   if (t.includes('early') && t.includes('check') && t.includes('out')) return 'early check out';
//   if (t.includes('late')  && t.includes('check') && t.includes('out')) return 'late check out';
//   if (t.includes('permission'))                 return 'permission';
//   if (t.includes('over') && t.includes('time')) return 'over time';
//   if (t.includes('half') && t.includes('day'))  return 'half day leave';
//   if (t.includes('comp') && t.includes('off'))  return 'comp off';
//   if (t.includes('leave'))                      return 'leave type';
//   return t;
// };
// const mapLeaveType = (txt: any) => {
//   const t = normStr(txt).toLowerCase();
//   if (t.includes('permission')) return 'Permission';
//   if (t.includes('over') && t.includes('time')) return 'Over Time';
//   if (t.includes('half') && t.includes('day'))  return 'Half Day Leave';
//   if (t.includes('comp') && t.includes('off'))  return 'Comp Off';
//   return 'Leave Type';
// };
// const overlaps = (aStart?: string | null, aEnd?: string | null, bStart?: string | null, bEnd?: string | null) => {
//   if (!aStart && !aEnd) return true;
//   const A1 = aStart || '0000-01-01';
//   const A2 = aEnd   || '9999-12-31';
//   const B1 = bStart || bEnd || '';
//   const B2 = bEnd   || bStart || '';
//   if (!B1) return true;
//   return (B1 <= A2) && (B2 >= A1);
// };

// /** GET /api/attendance/approvals */
// export const listApprovalRequests = async (req: Request, res: Response) => {
//   try {
//     const typeFilter   = normalizeType(req.query.type || 'All');
//     const statusRaw    = normStr(req.query.status || 'Pending');
//     const statusWanted = statusRaw.toLowerCase(); // pending|approved|rejected|all
//     const start        = (String(req.query.start || '').slice(0, 10)) || null;
//     const end          = (String(req.query.end   || '').slice(0, 10)) || null;

//     const empSnap = await db.collection(EMP_COL).get();
//     const empById: Record<string, any> = Object.fromEntries(empSnap.docs.map(d => [d.data().empid, d.data()]));
//     const shiftSnap = await db.collection(SHIFT_COL).get();
//     const shiftByGroup: Record<string, any> = Object.fromEntries(shiftSnap.docs.map(d => [d.data().group, d.data()]));

//     const out: any[] = [];

//     // ---------- NEW: Other Location tab ----------
//     if (typeFilter.includes('other_location')) {
//       let ref: FirebaseFirestore.Query = db.collection(OTHER_LOC_COL);
//       if (statusWanted !== 'all') ref = ref.where('approvalStatus', '==', statusRaw);
//       if (start) ref = ref.where('date', '>=', start);
//       if (end)   ref = ref.where('date', '<=', end);

//       const oSnap = await ref.get();
//       oSnap.forEach(d => {
//         const e = d.data() as any;
//         const emp = empById[e.empid] || {};
//         out.push({
//           source: 'attendance',
//           requestId: d.id,
//           type: 'Other Location',
//           empid: e.empid,
//           name: emp.name || e.name || '',
//           department: emp.dept || emp.department || '',
//           shift: emp.shift || (shiftByGroup[emp.shiftGroup || '']?.shift) || null,
//           shiftGroup: emp.shiftGroup || '',
//           requestTime: e.time || '',
//           requestDate: e.date || '',
//           reason: e.otherLocation || '-',
//           location: e.branchName || e.location || '-',
//           latitude: e.latitude ?? null,
//           longitude: e.longitude ?? null,
//           expectedLatitude: e.expectedLatitude ?? null,
//           expectedLongitude: e.expectedLongitude ?? null,
//           expectedRadius: e.expectedRadius ?? null,
//           distanceFromBranch: e.distanceFromBranch ?? null,
//           withinRadius: e.withinRadius ?? null,
//           status: e.approvalStatus || 'Pending',
//         });
//       });

//       out.sort((a, b) =>
//         String(b.requestDate || '').localeCompare(String(a.requestDate || '')) ||
//         String(b.requestTime || '').localeCompare(String(a.requestTime || ''))
//       );
//       return res.json(out);
//     }

//     // ---------- Attendance (late/early) ----------
//     let attRef: FirebaseFirestore.Query = db.collection(ATT_COL);
//     if (statusWanted !== 'all') attRef = attRef.where('approvalStatus', '==', statusRaw);
//     if (start) attRef = attRef.where('date', '>=', start);
//     if (end)   attRef = attRef.where('date', '<=', end);

//     const attSnap = await attRef.get();
//     attSnap.forEach(doc => {
//       const a = doc.data() as any;
//       const emp = empById[a.empid] || {};
//       const shift = shiftByGroup[emp.shiftGroup] || {};
//       const startTime = shift.startTime || '09:00';
//       const endTime   = shift.endTime   || '18:00';

//       let subType: string | null = null;
//       if (a.checkIn  && a.checkIn  > startTime) subType = 'Late check in';
//       if (a.checkOut && a.checkOut < endTime)   subType = 'Early check out';
//       else if (a.checkOut && a.checkOut > endTime) subType = 'Late check out';
//       if (!subType) return;
//       if (typeFilter !== 'all' && normalizeType(subType) !== typeFilter) return;

//       out.push({
//         source: 'attendance',
//         requestId: doc.id,
//         type: subType,
//         empid: a.empid,
//         name: emp.name || a.name || '',
//         department: emp.dept || emp.department || '',
//         shift: emp.shift || shift.shift || null,
//         shiftGroup: emp.shiftGroup || '',
//         requestTime: subType === 'Late check in' ? (a.checkIn || '') : (a.checkOut || ''),
//         requestDate: a.date,
//         reason: a.reason || '-',
//         location: a.location || '-',
//         checkInLatitude: a.checkInLatitude ?? null,
//         checkInLongitude: a.checkInLongitude ?? null,
//         checkInAccuracy: a.checkInAccuracy ?? null,
//         checkOutLatitude: a.checkOutLatitude ?? null,
//         checkOutLongitude: a.checkOutLongitude ?? null,
//         checkOutAccuracy: a.checkOutAccuracy ?? null,
//         branchName: a.branchName ?? null,
//         expectedLatitude: a.expectedLatitude ?? null,
//         expectedLongitude: a.expectedLongitude ?? null,
//         expectedRadius: a.expectedRadius ?? null,
//         distanceFromBranch: a.distanceFromBranch ?? null,
//         withinRadius: a.withinRadius ?? null,
//         checkoutDistanceFromBranch: a.checkoutDistanceFromBranch ?? null,
//         checkoutWithinRadius: a.checkoutWithinRadius ?? null,
//         status: a.approvalStatus || 'Pending',
//       });
//     });

//     // ---------- Leaves ----------
//     const leaveSnap = await db.collection(LEAVE_COL).get();
//     leaveSnap.forEach(doc => {
//       const L = doc.data() as any;
//       const emp = empById[L.empid] || {};

//       const sNorm = normStr(L.approvalStatus ?? L.status ?? 'Pending').toLowerCase();
//       if (statusWanted !== 'all' && sNorm !== statusWanted) return;

//       const friendlyType = mapLeaveType(L.type);
//       const dStart = toISO(L.startDate || L.date || L.selectDate);
//       const dEnd   = toISO(L.endDate   || dStart);
//       if (!overlaps(start, end, dStart, dEnd)) return;
//       if (typeFilter !== 'all' && normalizeType(friendlyType) !== typeFilter) return;

//       out.push({
//         source: 'leaves',
//         requestId: doc.id,
//         type: friendlyType,
//         empid: L.empid,
//         name: emp.name || L.name || '',
//         department: emp.dept || emp.department || L.department || '',
//         shift: emp.shift || null,
//         shiftGroup: emp.shiftGroup || '',
//         requestTime: L.time || L.requestTime || '',
//         requestDate: dStart || '',
//         reason: L.reason || '-',
//         location: L.location || '-',
//         latitude: L.latitude || null,
//         longitude: L.longitude || null,
//         status: L.approvalStatus ?? L.status ?? 'Pending',
//       });
//     });

//     out.sort((a, b) => String(b.requestDate || '').localeCompare(String(a.requestDate || '')));
//     return res.json(out);
//   } catch (err: any) {
//     console.error('listApprovalRequests error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** Alias used by your router for /api/attendance/approvals */
// export const listApprovals = (req: Request, res: Response) => listApprovalRequests(req, res);

// /** POST /api/attendance/approvals/decision */
// export const decideApproval = async (req: Request, res: Response) => {
//   try {
//     const { source, attendanceId, leaveId, empid, date, status, remarks, id, requestId } = req.body || {};
//     const clean = normStr(status);
//     if (!['Approved', 'Rejected'].includes(clean)) {
//       return res.status(400).json({ error: 'status must be Approved or Rejected' });
//     }
//     if (!source || !['attendance', 'leaves'].includes(source)) {
//       return res.status(400).json({ error: 'source must be attendance or leaves' });
//     }

//     // Try to resolve a generic id first (may belong to attendance OR otherLocation)
//     const genericId = String(id || requestId || '');

//     if (source === 'attendance') {
//       // If an explicit attendanceId is supplied, use it
//       if (attendanceId) {
//         await db.collection(ATT_COL).doc(String(attendanceId)).update({
//           approvalStatus: clean,
//           decisionBy: getReqEmpId(req),
//           decisionAt: admin.firestore.FieldValue.serverTimestamp(),
//           decisionRemarks: remarks || null,
//         });
//         return res.json({ message: `Attendance ${clean.toLowerCase()} successfully` });
//       }

//       // If we have a generic id, try attendance first, then otherLocation
//       if (genericId) {
//         const attRef = db.collection(ATT_COL).doc(genericId);
//         const attDoc = await attRef.get();
//         if (attDoc.exists) {
//           await attRef.update({
//             approvalStatus: clean,
//             decisionBy: getReqEmpId(req),
//             decisionAt: admin.firestore.FieldValue.serverTimestamp(),
//             decisionRemarks: remarks || null,
//           });
//           return res.json({ message: `Attendance ${clean.toLowerCase()} successfully` });
//         }

//         const olRef = db.collection(OTHER_LOC_COL).doc(genericId);
//         const olDoc = await olRef.get();
//         if (olDoc.exists) {
//           await olRef.update({
//             approvalStatus: clean,
//             decisionBy: getReqEmpId(req),
//             decisionAt: admin.firestore.FieldValue.serverTimestamp(),
//             decisionRemarks: remarks || null,
//             updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//           });
//           return res.json({ message: `Other-location ${clean.toLowerCase()} successfully` });
//         }
//       }

//       // Finally, try by (empid,date)
//       if (empid && date) {
//         const q = await db.collection(ATT_COL)
//           .where('empid', '==', empid)
//           .where('date', '==', date)
//           .limit(1).get();
//         if (q.empty) return res.status(404).json({ error: 'Attendance record not found' });

//         await q.docs[0].ref.update({
//           approvalStatus: clean,
//           decisionBy: getReqEmpId(req),
//           decisionAt: admin.firestore.FieldValue.serverTimestamp(),
//           decisionRemarks: remarks || null,
//         });
//         return res.json({ message: `Attendance ${clean.toLowerCase()} successfully` });
//       }

//       return res.status(400).json({ error: 'attendanceId or (id/requestId) or (empid & date) required' });
//     }

//     // Leaves
//     if (!leaveId) return res.status(400).json({ error: 'leaveId required' });
//     await db.collection(LEAVE_COL).doc(String(leaveId)).update({
//       approvalStatus: clean,
//       decisionBy: getReqEmpId(req),
//       decisionAt: admin.firestore.FieldValue.serverTimestamp(),
//       decisionRemarks: remarks || null,
//     });
//     return res.json({ message: `Leave ${clean.toLowerCase()} successfully` });
//   } catch (err: any) {
//     console.error('decideApproval error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /* ============================== NEW: Other Location routes (optional) ============================== */

// /** GET /api/attendance/other-location?status=Pending|Approved|Rejected|All&start=YYYY-MM-DD&end=YYYY-MM-DD */
// export const listOtherLocationEvents = async (req: Request, res: Response) => {
//   try {
//     const statusRaw = normStr(req.query.status || 'Pending');
//     const want = statusRaw.toLowerCase(); // pending|approved|rejected|all
//     const start = (String(req.query.start || '').slice(0, 10)) || null;
//     const end   = (String(req.query.end   || '').slice(0, 10)) || null;

//     let ref: FirebaseFirestore.Query = db.collection(OTHER_LOC_COL);
//     if (want !== 'all') ref = ref.where('approvalStatus', '==', statusRaw);
//     if (start) ref = ref.where('date', '>=', start);
//     if (end)   ref = ref.where('date', '<=', end);

//     const snap = await ref.get();
//     const rows = snap.docs.map(d => ({ id: d.id, ...d.data() }));

//     rows.sort((a: any, b: any) =>
//       String(b.date || '').localeCompare(String(a.date || '')) ||
//       String(b.time || '').localeCompare(String(a.time || ''))
//     );

//     return res.json(rows);
//   } catch (err: any) {
//     console.error('listOtherLocationEvents error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** POST /api/attendance/other-location/decision { id, status: 'Approved'|'Rejected', remarks? } */
// export const decideOtherLocationEvent = async (req: Request, res: Response) => {
//   try {
//     const { id, status, remarks } = req.body || {};
//     const clean = normStr(status);
//     if (!id) return res.status(400).json({ error: 'id required' });
//     if (!['Approved', 'Rejected'].includes(clean)) {
//       return res.status(400).json({ error: 'status must be Approved or Rejected' });
//     }

//     await db.collection(OTHER_LOC_COL).doc(String(id)).update({
//       approvalStatus: clean,
//       decisionBy: getReqEmpId(req),
//       decisionAt: admin.firestore.FieldValue.serverTimestamp(),
//       decisionRemarks: remarks || null,
//       updatedAt: admin.firestore.FieldValue.serverTimestamp(),
//     });

//     return res.json({ message: `Other-location ${clean.toLowerCase()} successfully` });
//   } catch (err: any) {
//     console.error('decideOtherLocationEvent error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };

// /** GET /api/attendance/my-requests */
// export const listMyRequests = async (req: Request, res: Response) => {
//   try {
//     const empid = getReqEmpId(req);
//     if (!empid) return res.status(401).json({ message: 'Unauthorized' });

//     const statusQ = normStr(req.query.status || 'All');
//     const wantStatus = statusQ.toLowerCase();
//     const start = (String(req.query.start || '').slice(0, 10));
//     const end   = (String(req.query.end   || '').slice(0, 10));
//     const singleDay = !!(start && end && start === end);

//     const shiftsSnap = await db.collection(SHIFT_COL).get();
//     const shiftByGroup: Record<string, any> = {};
//     shiftsSnap.forEach(d => { const s = d.data(); (shiftByGroup as any)[(s as any).group] = s; });

//     let emp: any = null;
//     const eSnap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
//     if (!eSnap.empty) emp = eSnap.docs[0].data();

//     const out: any[] = [];

//     let attRef: FirebaseFirestore.Query = db.collection(ATT_COL).where('empid', '==', empid);
//     if (start) attRef = attRef.where('date', '>=', start);
//     if (end)   attRef = attRef.where('date', '<=', end);
//     const attSnap = await attRef.get();

//     attSnap.forEach(doc => {
//       const a = doc.data() as any;

//       const sNorm = normStr(a.approvalStatus || 'Pending').toLowerCase();
//       if (wantStatus !== 'all' && sNorm !== wantStatus) return;
//       if (singleDay && a.date !== start) return;

//       const shift = shiftByGroup[emp?.shiftGroup] || {};
//       const startTime = shift.startTime || '09:00';
//       const endTime   = shift.endTime   || '18:00';

//       let subType: string | null = null;
//       if (a.checkIn  && a.checkIn  > startTime) subType = 'Late check in';
//       else if (a.checkOut && a.checkOut < endTime) subType = 'Early check out';
//       else if (a.checkOut && a.checkOut > endTime) subType = 'Late check out';

//       out.push({
//         source: 'attendance',
//         requestId: doc.id,
//         type: subType || 'Attendance',
//         empid: a.empid,
//         name: a.name || '',
//         requestDate: a.date,
//         requestTime:
//           subType === 'Late check in' ? (a.checkIn || '') :
//           (subType === 'Late check out' || subType === 'Early check out') ? (a.checkOut || '') : '',
//         reason: a.reason || '-',
//         location: a.location || '-',
//         checkInLatitude: a.checkInLatitude ?? null,
//         checkInLongitude: a.checkInLongitude ?? null,
//         checkInAccuracy: a.checkInAccuracy ?? null,
//         checkOutLatitude: a.checkOutLatitude ?? null,
//         checkOutLongitude: a.checkOutLongitude ?? null,
//         checkOutAccuracy: a.checkOutAccuracy ?? null,
//         branchName: a.branchName ?? null,
//         expectedLatitude: a.expectedLatitude ?? null,
//         expectedLongitude: a.expectedLongitude ?? null,
//         expectedRadius: a.expectedRadius ?? null,
//         distanceFromBranch: a.distanceFromBranch ?? null,
//         withinRadius: a.withinRadius ?? null,
//         checkoutDistanceFromBranch: a.checkoutDistanceFromBranch ?? null,
//         checkoutWithinRadius: a.checkoutWithinRadius ?? null,
//         status: a.approvalStatus || 'Pending',
//       });
//     });

//     const leaveSnap = await db.collection(LEAVE_COL).where('empid', '==', empid).get();
//     leaveSnap.forEach(doc => {
//       const L = doc.data() as any;
//       const sNorm = normStr(L.approvalStatus ?? L.status ?? 'Pending').toLowerCase();
//       if (wantStatus !== 'all' && sNorm !== wantStatus) return;

//       const dStart = toISO(L.startDate || L.date || L.selectDate);
//       const dEnd   = toISO(L.endDate   || dStart);

//       if (singleDay) {
//         if (!(dStart && start >= dStart && start <= (dEnd || dStart))) return;
//       } else {
//         if (start && dEnd   && dEnd   < start) return;
//         if (end   && dStart && dStart > end)   return;
//       }

//       out.push({
//         source: 'leaves',
//         requestId: doc.id,
//         type: mapLeaveType(L.type),
//         empid: L.empid,
//         name: L.name || '',
//         requestDate: dStart || '',
//         requestTime: L.time || '',
//         reason: L.reason || '-',
//         location: L.location || '-',
//         latitude: L.latitude || null,
//         longitude: L.longitude || null,
//         status: L.approvalStatus ?? L.status ?? 'Pending',
//       });
//     });

//     out.sort((a, b) => String(b.requestDate || '').localeCompare(String(a.requestDate || '')));
//     return res.json(out);
//   } catch (err: any) {
//     console.error('listMyRequests error:', err);
//     return res.status(500).json({ error: err.message });
//   }
// };
import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

const db = admin.firestore();

/* ============================== Helpers ============================== */

const EMP_COL       = 'employees';
const ATT_COL       = 'attendance';
const LEAVE_COL     = 'leaves';
const SHIFT_COL     = 'shifts';
const OFFICE_COL    = 'officeLocations';
const OTHER_LOC_COL = 'otherLocation'; // separate collection for other-location events

function pad2(n: number | string) { return String(n).padStart(2, '0'); }

// --- Time helpers (IST + UTC) ---
// Use Intl with Asia/Kolkata instead of adding 5.5h manually.
const IST_TZ = 'Asia/Kolkata';

function toYMD(d: Date = new Date()): string {
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone: IST_TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return fmt.format(d); // YYYY-MM-DD
}

function nowTimeIST(): string {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: IST_TZ,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  })
    .formatToParts(new Date())
    .reduce<Record<string, string>>((acc, p) => {
      if (p.type !== 'literal') acc[p.type] = p.value;
      return acc;
    }, {});
  return `${parts.hour}:${parts.minute}:${parts.second}`; // HH:mm:ss
}

function nowUtcISO(): string {
  return new Date().toISOString(); // exact instant (UTC) for audits
}

function daysInMonth(year: number, month: number) { return new Date(year, month, 0).getDate(); }

/* ====== CHANGED: timezone-safe weekday detection for YYYY-MM-DD ======
   Avoid new Date('YYYY-MM-DD') which is parsed as UTC in Node.
   dayOfWeekFromYMD returns: 0=Sunday, 1=Monday, ..., 6=Saturday
*/
function dayOfWeekFromYMD(ymd: string): number {
  const y = parseInt(ymd.slice(0, 4), 10);
  const m = parseInt(ymd.slice(5, 7), 10);
  const d = parseInt(ymd.slice(8, 10), 10);
  let Y = y, M = m;
  if (M < 3) { M += 12; Y -= 1; }
  const K = Y % 100;
  const J = Math.floor(Y / 100);
  // Zeller’s congruence (Gregorian):
  // h = 0..6 => 0=Saturday,1=Sunday,2=Monday,...,6=Friday
  const h = (d + Math.floor((13 * (M + 1)) / 5) + K + Math.floor(K / 4) + Math.floor(J / 4) + 5 * J) % 7;
  // Convert to 0=Sunday..6=Saturday
  return (h + 6) % 7;
}
function isSunday(ymd: string) { return dayOfWeekFromYMD(ymd) === 0; } // <— callers unchanged

function cmpHHMM(a?: string, b?: string) { return (a || '00:00') > (b || '00:00'); }

function midpointHHMM(start?: string, end?: string) {
  const [h1, m1] = (start || '00:00').split(':').map(Number);
  const [h2, m2] = (end   || '23:59').split(':').map(Number);
  const s1 = h1 * 3600 + m1 * 60, s2 = h2 * 3600 + m2 * 60;
  const mid = Math.floor((s1 + s2) / 2);
  const mh = Math.floor(mid / 3600), mm = Math.floor((mid % 3600) / 60);
  return `${pad2(mh)}:${pad2(mm)}`;
}

function toISO(v: any): string {
  try {
    if (!v) return '';
    if (typeof v === 'string') return v.slice(0, 10);
    if (v.toDate && typeof v.toDate === 'function') return v.toDate().toISOString().slice(0, 10);
    const d = new Date(v);
    return d.toISOString().slice(0, 10);
  } catch { return ''; }
}
function eachYMD(start: string, end: string) {
  const out: string[] = [];
  const d = new Date(start);
  for (;;) {
    const ymd = d.toISOString().slice(0, 10);
    out.push(ymd);
    if (ymd === end) break;
    d.setDate(d.getDate() + 1);
  }
  return out;
}

// project-level holiday set (optional)
const HOLIDAYS_SET = new Set<string>([]);

/* ==== tolerant helpers for emp id ==== */
const pickEmpId = (obj: any): string | null => {
  const v = obj?.empid ?? obj?.empId ?? obj?.employeeId ?? null;
  return v ? String(v).trim() : null;
};
const getReqEmpId = (req: Request): string | null => {
  return pickEmpId((req as any).body) || pickEmpId((req as any).user) || null;
};

const normStr = (s: any) => String(s ?? '').trim();
const lower = (s: string) => s.trim().toLowerCase();

/* ============ GEO helpers ============ */

// Haversine distance in meters
function haversineMeters(lat1?: number|null, lon1?: number|null, lat2?: number|null, lon2?: number|null) {
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;
  const R = 6371000; // meters
  const toRad = (x: number) => (x * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return Math.round(R * c);
}

// find office by branch name (case-insensitive fallback)
async function findOfficeByBranchName(branchNameRaw: string) {
  const branchName = normStr(branchNameRaw);
  if (!branchName) return null;

  // Try exact match on branchName
  const exact = await db.collection(OFFICE_COL).where('branchName', '==', branchName).limit(1).get();
  if (!exact.empty) {
    const d = exact.docs[0];
    return { id: d.id, ...d.data() } as any;
  }

  // Fallback: load a small page & do case-insensitive compare
  const snap = await db.collection(OFFICE_COL).limit(50).get();
  for (const d of snap.docs) {
    const data = d.data() as any;
    const bn = normStr(data.branchName || data.name || '');
    if (lower(bn) === lower(branchName)) {
      return { id: d.id, ...data };
    }
  }
  return null;
}

/* ============================== NEW: Other Location capture ============================== */

type OtherLocEventType = 'check-in' | 'check-out';

async function createOtherLocationEvent(params: {
  empid: string;
  name: string;
  date: string;
  time: string;
  type: OtherLocEventType;
  branchName: string | null;

  // device coords at event time
  latitude: number | null;
  longitude: number | null;
  accuracy?: number | null;

  // expected (branch) snapshot
  expectedLatitude: number | null;
  expectedLongitude: number | null;
  expectedRadius: number | null;

  // computed deltas
  distanceFromBranch: number | null;
  withinRadius: boolean | null;

  // text reason
  otherLocation: string | null;
}) {
  const payload = {
    source: 'attendance' as const,
    approvalStatus: 'Pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),

    empid: params.empid,
    name: params.name,
    date: params.date,
    time: params.time,
    type: params.type,
    branchName: params.branchName,

    // device
    latitude: params.latitude,
    longitude: params.longitude,
    accuracy: params.accuracy ?? null,

    // expected snapshot
    expectedLatitude: params.expectedLatitude,
    expectedLongitude: params.expectedLongitude,
    expectedRadius: params.expectedRadius,

    // deltas
    distanceFromBranch: params.distanceFromBranch,
    withinRadius: params.withinRadius,

    otherLocation: params.otherLocation,
  };
  await db.collection(OTHER_LOC_COL).add(payload as any);
}

/* ============================== Core attendance (string-time model) ============================== */

/** Get current user (from req.user) */
export const getCurrentUser = async (req: Request, res: Response) => {
  try {
    const empid = getReqEmpId(req);
    const snap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
    if (snap.empty) return res.status(404).json({ error: 'Employee not found' });
    const d = snap.docs[0].data();
    return res.json({
      empid: d.empid,
      name:  d.name,
      role:  (req as any).user?.role,
      shiftGroup: d.shiftGroup,
    });
  } catch (err: any) {
    console.error('getCurrentUser error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** POST /api/attendance/check-in */
export const checkIn = async (req: Request, res: Response) => {
  const empid    = getReqEmpId(req) || '';
  const name     = normStr((req.body as any)?.name);
  const location = normStr((req.body as any)?.location); // should be branch name

  // coordinates from app
  const checkInLatitude  = typeof (req.body as any)?.latitude  === 'number' ? (req.body as any).latitude  : null;
  const checkInLongitude = typeof (req.body as any)?.longitude === 'number' ? (req.body as any).longitude : null;
  const checkInAccuracy  = typeof (req.body as any)?.accuracy  === 'number' ? (req.body as any).accuracy  : null;
  const checkInSource    = normStr((req.body as any)?.source) || null; // manual/biometric

  // ===== NEW: Reason coming from client (dropdown) =====
  const reasonId        = normStr((req.body as any)?.reasonId) || null;
  const reasonText      = normStr((req.body as any)?.reasonText || (req.body as any)?.reason) || null;
  const reasonTypeId    = normStr((req.body as any)?.reasonTypeId) || null;
  const reasonTypeName  = normStr((req.body as any)?.reasonTypeName) || null;

  if (!empid || !name || !location) {
    return res.status(400).json({ error: 'empid, name and location are required' });
  }
  const today = toYMD(new Date());

  try {
    // 1) find/create today's doc
    const snap = await db.collection(ATT_COL)
      .where('empid', '==', empid)
      .where('date', '==', today)
      .limit(1)
      .get();

    const nowTime = nowTimeIST(); // HH:mm:ss (IST)

    // 2) figure out branch to compare against (prefer request, fallback employee.profile)
    let branchName = location;
    const empSnap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
    const empRow = empSnap.empty ? null : empSnap.docs[0].data();
    if (!branchName && (empRow as any)?.location) branchName = normStr((empRow as any).location);

    // 3) find office & compute distance
    let expectedLatitude: number | null = null;
    let expectedLongitude: number | null = null;
    let expectedRadius: number | null = null;
    let distanceFromBranch: number | null = null;
    let withinRadius: boolean | null = null;
    let otherLocation: string | null = null;

    const office = await findOfficeByBranchName(branchName);
    if (office) {
      expectedLatitude  = Number((office as any).latitude ?? 0) || 0;
      expectedLongitude = Number((office as any).longitude ?? 0) || 0;
      expectedRadius    = Number((office as any).radius ?? 0) || 0;

      distanceFromBranch = haversineMeters(
        checkInLatitude, checkInLongitude, expectedLatitude, expectedLongitude
      );

      if (distanceFromBranch != null && expectedRadius != null) {
        withinRadius = distanceFromBranch <= expectedRadius;
        if (!withinRadius) {
          otherLocation = `Outside radius by ${Math.max(0, distanceFromBranch - expectedRadius)} m`;
        }
      }
    } else {
      // branch not configured
      otherLocation = 'No matching branch in officeLocations';
    }

    // 4) write attendance record + capture other-location event when needed
    if (!snap.empty) {
      const doc = snap.docs[0];
      const data = doc.data();

      if (data.checkIn) {
        // still push/update reason if provided (no harm)
        if (reasonText) {
          await doc.ref.set({
            reason: reasonText,
            reasonId: reasonId || null,
            reasonTypeId: reasonTypeId || null,
            reasonTypeName: reasonTypeName || null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }

        if (!empSnap.empty) {
          await empSnap.docs[0].ref.set(
            { status: 'active', updatedAt: admin.firestore.FieldValue.serverTimestamp() },
            { merge: true }
          );
        }
        if (withinRadius === false || (otherLocation && otherLocation.trim() !== '')) {
          await createOtherLocationEvent({
            empid, name, date: today, time: nowTime, type: 'check-in',
            branchName,
            latitude: checkInLatitude, longitude: checkInLongitude, accuracy: checkInAccuracy,
            expectedLatitude, expectedLongitude, expectedRadius,
            distanceFromBranch, withinRadius, otherLocation
          });
        }
        return res.status(200).json({
          message: 'Already checked in today',
          code: 'ALREADY_CHECKED_IN',
          attendanceId: doc.id,
          record: { id: doc.id, ...data },
        });
      }

      await doc.ref.update({
        checkIn: nowTime,
        checkInTsUtc: nowUtcISO(),              // <<< AUDIT FIELD
        name,
        location: branchName,
        checkInLatitude,
        checkInLongitude,
        checkInAccuracy,
        checkInSource,
        branchName: branchName || null,
        expectedLatitude,
        expectedLongitude,
        expectedRadius,
        distanceFromBranch,
        withinRadius,
        otherLocation,
        // ===== NEW: persist reason to attendance =====
        ...(reasonText ? { reason: reasonText } : {}),
        ...(reasonId ? { reasonId } : {}),
        ...(reasonTypeId ? { reasonTypeId } : {}),
        ...(reasonTypeName ? { reasonTypeName } : {}),
        status: 'Present',
        approvalStatus: 'Pending',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (withinRadius === false || (otherLocation && otherLocation.trim() !== '')) {
        await createOtherLocationEvent({
          empid, name, date: today, time: nowTime, type: 'check-in',
          branchName,
          latitude: checkInLatitude, longitude: checkInLongitude, accuracy: checkInAccuracy,
          expectedLatitude, expectedLongitude, expectedRadius,
          distanceFromBranch, withinRadius, otherLocation
        });
      }

      if (!empSnap.empty) {
        await empSnap.docs[0].ref.update({
          status: 'active',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      return res.json({ message: 'Check-in updated' });
    }

    // new record
    await db.collection(ATT_COL).add({
      empid,
      name,
      date: today,
      checkIn: nowTime,
      checkInTsUtc: nowUtcISO(),                // <<< AUDIT FIELD
      location: branchName,
      checkInLatitude,
      checkInLongitude,
      checkInAccuracy,
      checkInSource,
      branchName: branchName || null,
      expectedLatitude,
      expectedLongitude,
      expectedRadius,
      distanceFromBranch,
      withinRadius,
      otherLocation,
      // ===== NEW: persist reason to attendance =====
      ...(reasonText ? { reason: reasonText } : {}),
      ...(reasonId ? { reasonId } : {}),
      ...(reasonTypeId ? { reasonTypeId } : {}),
      ...(reasonTypeName ? { reasonTypeName } : {}),
      status: 'Present',
      approvalStatus: 'Pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (withinRadius === false || (otherLocation && otherLocation.trim() !== '')) {
      await createOtherLocationEvent({
        empid, name, date: today, time: nowTime, type: 'check-in',
        branchName,
        latitude: checkInLatitude, longitude: checkInLongitude, accuracy: checkInAccuracy,
        expectedLatitude, expectedLongitude, expectedRadius,
        distanceFromBranch, withinRadius, otherLocation
      });
    }

    const empSnap2 = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
    if (!empSnap2.empty) {
      await empSnap2.docs[0].ref.update({
        status: 'active',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return res.json({ message: 'Checked-in successfully' });
  } catch (err: any) {
    console.error('checkIn error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** POST /api/attendance/check-out */
export const checkOut = async (req: Request, res: Response) => {
  const empid    = getReqEmpId(req) || '';
  const location = normStr((req.body as any)?.location);

  const checkOutLatitude  = typeof (req.body as any)?.latitude  === 'number' ? (req.body as any).latitude  : null;
  const checkOutLongitude = typeof (req.body as any)?.longitude === 'number' ? (req.body as any).longitude : null;
  const checkOutAccuracy  = typeof (req.body as any)?.accuracy  === 'number' ? (req.body as any).accuracy  : null;

  // ===== NEW: Reason coming from client (dropdown) for checkout as well =====
  const reasonId        = normStr((req.body as any)?.reasonId) || null;
  const reasonText      = normStr((req.body as any)?.reasonText || (req.body as any)?.reason) || null;
  const reasonTypeId    = normStr((req.body as any)?.reasonTypeId) || null;
  const reasonTypeName  = normStr((req.body as any)?.reasonTypeName) || null;

  if (!empid || !location) {
    return res.status(400).json({ error: 'empid and location are required' });
  }
  const today = toYMD(new Date());

  try {
    const snap = await db.collection(ATT_COL)
      .where('empid', '==', empid)
      .where('date', '==', today)
      .limit(1)
      .get();

    if (snap.empty) return res.status(400).json({ error: 'You need to check in first' });

    const doc = snap.docs[0];
    if (doc.data().checkOut) {
      // still allow saving/overriding reason if sent
      if (reasonText) {
        await doc.ref.set({
          reason: reasonText,
          reasonId: reasonId || null,
          reasonTypeId: reasonTypeId || null,
          reasonTypeName: reasonTypeName || null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      return res.status(400).json({ error: 'Already checked out today' });
    }

    const current = doc.data() as any;
    const branchName = normStr(current.branchName || location || current.location || '');

    let expectedLatitude: number | null = current.expectedLatitude ?? null;
    let expectedLongitude: number | null = current.expectedLongitude ?? null;
    let expectedRadius: number | null = current.expectedRadius ?? null;

    if (expectedLatitude == null || expectedLongitude == null || expectedRadius == null) {
      const office = await findOfficeByBranchName(branchName);
      if (office) {
        expectedLatitude  = Number((office as any).latitude ?? 0) || 0;
        expectedLongitude = Number((office as any).longitude ?? 0) || 0;
        expectedRadius    = Number((office as any).radius ?? 0) || 0;
      }
    }

    const checkoutDistanceFromBranch = haversineMeters(checkOutLatitude, checkOutLongitude, expectedLatitude, expectedLongitude);
    const checkoutWithinRadius = (checkoutDistanceFromBranch != null && expectedRadius != null)
      ? checkoutDistanceFromBranch <= expectedRadius
      : null;

    const nowTime = nowTimeIST();

    await doc.ref.update({
      checkOut: nowTime,
      checkOutTsUtc: nowUtcISO(),               // <<< AUDIT FIELD
      location: branchName,
      checkOutLatitude,
      checkOutLongitude,
      checkOutAccuracy,
      branchName,
      expectedLatitude,
      expectedLongitude,
      expectedRadius,
      checkoutDistanceFromBranch,
      checkoutWithinRadius,
      // ===== NEW: persist reason to attendance on checkout as well =====
      ...(reasonText ? { reason: reasonText } : {}),
      ...(reasonId ? { reasonId } : {}),
      ...(reasonTypeId ? { reasonTypeId } : {}),
      ...(reasonTypeName ? { reasonTypeName } : {}),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (checkoutWithinRadius === false) {
      await createOtherLocationEvent({
        empid,
        name: normStr(current.name || ''),
        date: today,
        time: nowTime,
        type: 'check-out',
        branchName,
        latitude: checkOutLatitude,
        longitude: checkOutLongitude,
        accuracy: checkOutAccuracy,
        expectedLatitude,
        expectedLongitude,
        expectedRadius,
        distanceFromBranch: checkoutDistanceFromBranch,
        withinRadius: checkoutWithinRadius,
        otherLocation: `Outside radius by ${Math.max(0, (checkoutDistanceFromBranch ?? 0) - (expectedRadius ?? 0))} m`,
      });
    }

    const empSnap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
    if (!empSnap.empty) {
      await empSnap.docs[0].ref.update({
        status: 'inactive',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return res.json({ message: 'Checked-out & set inactive' });
  } catch (err: any) {
    console.error('checkOut error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** GET /api/attendance/live */
export const getLiveAttendance = async (req: Request, res: Response) => {
  const today = toYMD(new Date());
  const isAdmin = (req as any).user?.role === 'admin';

  try {
    let employees: any[] = [];
    if (isAdmin) {
      const empSnap = await db.collection(EMP_COL).get();
      employees = empSnap.docs.map(d => d.data());
    } else {
      const empid = getReqEmpId(req);
      const empSnap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
      if (empSnap.empty) return res.json([]);
      employees = [empSnap.docs[0].data()];
    }

    const attSnap = await db.collection(ATT_COL).where('date', '==', today).get();
    const attMap: Record<string, any> = Object.fromEntries(attSnap.docs.map(d => [d.data().empid, d.data()]));

    const leaveSnap = await db.collection(LEAVE_COL)
      .where('approvalStatus', '==', 'Approved')
      .where('startDate', '<=', today)
      .get();
    const validLeaves = leaveSnap.docs
      .map(d => d.data())
      .filter(l => (toISO((l as any).endDate) || toISO((l as any).startDate)) >= today)
      .map(l => (l as any).empid);
    const leaveSet = new Set(validLeaves);

    const shiftsSnap = await db.collection(SHIFT_COL).get();
    const shiftByGroup: Record<string, any> =
      Object.fromEntries(shiftsSnap.docs.map(d => [d.data().group, d.data()]));

    const isHoliday = HOLIDAYS_SET.has(today);
    const isWeekOff = isSunday(today); // <— now IST-safe

    const result = employees.map(emp => {
      const rec = attMap[(emp as any).empid];
      let status: string;
      let isLate = false, isEarly = false;

      let permissionCount = Array.isArray(rec?.permissionRequests)
        ? rec.permissionRequests.length
        : (rec?.permissionRequest ? 1 : 0);

      if (isHoliday) status = 'Holiday';
      else if (isWeekOff) status = 'WeekOff';
      else if (leaveSet.has((emp as any).empid)) status = 'Leave';
      else if (rec?.checkIn) {
        status = 'Present';
        const shift = shiftByGroup[(emp as any).shiftGroup] || {};
        const start = shift.startTime || '09:00';
        const end   = shift.endTime   || '18:00';
        isLate  = rec.checkIn  > start;
        isEarly = rec.checkOut && rec.checkOut < end;
      } else {
        status = 'Absent';
      }

      let isHalfDay = false;
      if (status === 'Present' && shiftByGroup[(emp as any).shiftGroup]) {
        const [h1, m1] = (shiftByGroup[(emp as any).shiftGroup].startTime || '09:00').split(':').map(Number);
        const [h2, m2] = (shiftByGroup[(emp as any).shiftGroup].endTime   || '18:00').split(':').map(Number);
        const midSec = ((h1 * 3600 + m1 * 60) + (h2 * 3600 + m2 * 60)) / 2;
        const inSec = rec && rec.checkIn
          ? rec.checkIn.split(':').reduce((a: number, v: string, i: number) => a + (+v) * (i === 0 ? 3600 : 60), 0)
          : 0;
        isHalfDay = inSec > midSec;
      }

      return {
        empid:          (emp as any).empid,
        name:           (emp as any).name,
        shiftGroup:     (emp as any).shiftGroup,
        date:           today,
        status,
        checkIn:        rec?.checkIn || null,
        checkOut:       rec?.checkOut || null,
        late:           isLate,
        early:          isEarly,
        permissionCount,
        leave:          status === 'Leave',
        holiday:        status === 'Holiday',
        weekOff:        status === 'WeekOff',
        halfDay:        isHalfDay,
        branchName:                 rec?.branchName ?? null,
        withinRadius:               rec?.withinRadius ?? null,
        distanceFromBranch:         rec?.distanceFromBranch ?? null,
        checkoutWithinRadius:       rec?.checkoutWithinRadius ?? null,
        checkoutDistanceFromBranch: rec?.checkoutDistanceFromBranch ?? null,
      };
    });

    return res.json(result);
  } catch (err: any) {
    console.error('getLiveAttendance error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** GET /api/attendance/employee/:empid */
export const getEmployeeAttendance = async (req: Request, res: Response) => {
  const { empid } = req.params;
  try {
    const snap = await db.collection(ATT_COL)
      .where('empid', '==', empid)
      .orderBy('date', 'desc').get();
    const records = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    return res.json(records);
  } catch (err: any) {
    console.error('getEmployeeAttendance error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** Admin: list all attendance records */
export const getAllAttendance = async (_req: Request, res: Response) => {
  try {
    const snap = await db.collection(ATT_COL).get();
    const records = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    return res.json(records);
  } catch (err: any) {
    console.error('getAllAttendance error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** Admin: approve/reject an attendance row by document id */
export const approveAttendance = async (req: Request, res: Response) => {
  const { id, status } = req.body as { id: string; status: 'Approved' | 'Rejected' | string };
  try {
    await db.collection(ATT_COL).doc(id).update({
      approvalStatus: status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return res.json({ message: `Attendance ${String(status).toLowerCase()} successfully` });
  } catch (err: any) {
    console.error('approveAttendance error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** GET /api/attendance/monthly/:empid/:year/:month */
export const getMonthlySummary = async (req: Request, res: Response) => {
  const { empid, year, month } = req.params as any;
  try {
    const snap = await db.collection(ATT_COL)
      .where('empid', '==', empid)
      .where('date', '>=', `${year}-${month}-01`)
      .where('date', '<=', `${year}-${month}-31`)
      .get();
    const records = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    return res.json(records);
  } catch (err: any) {
    console.error('getMonthlySummary error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** GET /api/attendance/roster?date=YYYY-MM-DD */
export const getDailyRoster = async (req: Request, res: Response) => {
  const date = String(req.query.date || '');
  if (!date) return res.status(400).json({ error: 'Missing ?date=YYYY-MM-DD' });

  try {
    const empSnap = await db.collection(EMP_COL).get();
    const employees = empSnap.docs.map(d => d.data());

    const attSnap = await db.collection(ATT_COL).where('date', '==', date).get();
    const attByEmp: Record<string, any> = Object.fromEntries(attSnap.docs.map(d => [d.data().empid, d.data()]));

    const roster = employees.map((emp: any) => {
      const rec = attByEmp[emp.empid];
      let raw = 'Absent';
      if (rec?.approvalStatus === 'Approved' && !rec.checkIn) raw = 'Leave';
      else if (rec?.checkIn) raw = rec.checkIn > '09:00' ? 'Late' : 'Present';
      return {
        empid:      emp.empid,
        name:       emp.name || '',
        shiftGroup: emp.shiftGroup,
        status:     (raw === 'Present' || raw === 'Late') ? 'active' : 'inactive',
      };
    });

    return res.json(roster);
  } catch (err: any) {
    console.error('getDailyRoster error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** GET /api/attendance/range-summary?start=YYYY-MM-DD&end=YYYY-MM-DD */
export const getRangeSummary = async (req: Request, res: Response) => {
  try {
    const start = String(req.query.start || '').slice(0, 10);
    const end   = String(req.query.end   || '').slice(0, 10);
    if (!start || !end || new Date(end) < new Date(start)) {
      return res.status(400).json({ error: 'Provide ?start=YYYY-MM-DD&end=YYYY-MM-DD' });
    }

    const empSnap = await db.collection(EMP_COL).get();
    const employees = empSnap.docs.map(d => d.data());

    const activeEmployees = employees.filter((e: any) =>
      String(e.status || '').toLowerCase() === 'active'
    ).length;

    const shiftsSnap = await db.collection(SHIFT_COL).get();
    const shiftByGroup: Record<string, any> =
      Object.fromEntries(shiftsSnap.docs.map(d => [d.data().group, d.data()]));

    const attSnap = await db.collection(ATT_COL)
      .where('date', '>=', start).where('date', '<=', end).get();
    const attByEmpDate: Record<string, any> = {};
    attSnap.forEach(doc => { const a = doc.data(); attByEmpDate[`${(a as any).empid}|${(a as any).date}`] = { id: doc.id, ...a }; });

    const leavesSnap = await db.collection(LEAVE_COL).get();
    const approvedLeaves = leavesSnap.docs
      .map(d => d.data())
      .filter((L: any) => String(L.approvalStatus ?? L.status ?? 'Pending').toLowerCase() === 'approved')
      .map((L: any) => ({
        empid: L.empid,
        type: String(L.type || ''),
        start: toISO(L.startDate || L.selectDate || L.date),
        end:   toISO(L.endDate   || L.selectDate || L.date || L.startDate),
      }));

    const leaveDays = new Set<string>();
    let onLeaveCount = 0;
    for (const L of approvedLeaves) {
      if (!L.start) continue;
      const s = L.start, e = L.end || L.start;
      if (e < start || s > end) continue;
      for (const d of eachYMD((s < start ? start : s), (e > end ? end : e))) {
        leaveDays.add(`${L.empid}|${d}`); onLeaveCount++;
      }
    }

    let checkedIn = 0, absent = 0, lateIn = 0, earlyOut = 0, halfDay = 0, presentApproved = 0, holiday = 0, weekOff = 0;
    const rows: any[] = [];
    const dates = eachYMD(start, end);

    for (const ymd of dates) {
      const isHoliday = HOLIDAYS_SET.has(ymd);
      const isWO = isSunday(ymd); // <— now IST-safe
      if (isHoliday) holiday++;
      if (isWO) weekOff++;

      for (const emp of employees) {
        const key   = `${(emp as any).empid}|${ymd}`;
        const att   = attByEmpDate[key] || null;
        const shift = shiftByGroup[(emp as any).shiftGroup] || { startTime: '09:00', endTime: '18:00' };
        const startT = shift.startTime || '09:00';
        const endT   = shift.endTime   || '18:00';
        const mid    = midpointHHMM(startT, endT);

        let status = 'Absent';
        let isLate = false, isEarly = false;

        if (isHoliday) {
          status = 'Holiday';
        } else if (isWO) {
          status = 'WeekOff';
        } else if (leaveDays.has(key)) {
          status = approvedLeaves.find(l =>
            (l as any).empid === (emp as any).empid && (l as any).start <= ymd && ymd <= ((l as any).end || (l as any).start) && (l as any).type.toLowerCase().includes('half')
          ) ? 'Half Day' : 'On Leave';
          if (status === 'Half Day') halfDay++;
        } else if (att?.checkIn) {
          checkedIn++;
          status = 'Present';
          if (cmpHHMM(att.checkIn as any, startT)) { isLate = true; lateIn++; }
          if ((att as any).checkOut && !cmpHHMM((att as any).checkOut, endT)) { isEarly = true; earlyOut++; }
          if (cmpHHMM(att.checkIn as any, mid)) { status = 'Half Day'; halfDay++; }
          if (String((att as any).approvalStatus || '').toLowerCase() === 'approved') presentApproved++;
        } else {
          absent++;
        }

        rows.push({
          employeeId:  (emp as any).empid,
          employeeName: (emp as any).name || '',
          shift:       (emp as any).shift || (emp as any).shiftGroup || '',
          date:        ymd,
          checkIn:     (att as any)?.checkIn || '-',
          checkOut:    (att as any)?.checkOut || '-',
          department:  (emp as any).dept || (emp as any).department || '',
          attendance:  status,
          workedHours: (att as any)?.workedHours ? String((att as any).workedHours) : '-',
          late:        isLate,
          early:       isEarly,
          approval:    (att as any)?.approvalStatus || 'Pending',
        });
      }
    }

    return res.json({
      counts: {
        activeEmployees,
        onLeave: onLeaveCount,
        checkedIn,
        absent,
        lateCheckIn: lateIn,
        earlyCheckOut: earlyOut,
        halfDay,
        present: presentApproved,
        holiday,
        weekOff,
      },
      rows,
    });
  } catch (err: any) {
    console.error('getRangeSummary error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** GET /api/attendance/month-view/:empid/:year/:month */
export const getMonthView = async (req: Request, res: Response) => {
  try {
    const { empid, year, month } = req.params as any;
    const y = parseInt(year, 10);
    const m = parseInt(month, 10);
    if (!empid || !y || !m) return res.status(400).json({ error: 'Bad params' });

    const first = `${year}-${month}-01`;
    const last  = `${year}-${month}-${pad2(daysInMonth(y, m))}`;

    const empSnap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
    if (empSnap.empty) return res.status(404).json({ error: 'Employee not found' });
    const emp = empSnap.docs[0].data();

    const shiftSnap = await db.collection(SHIFT_COL).where('group', '==', (emp as any).shiftGroup).limit(1).get();
    const shift = shiftSnap.empty ? {} : shiftSnap.docs[0].data();
    const shiftStart = (shift as any).startTime || '09:00';
    const shiftEnd   = (shift as any).endTime   || '18:00';
    const mid        = midpointHHMM(shiftStart, shiftEnd);

    const attSnap = await db.collection(ATT_COL)
      .where('empid', '==', empid)
      .where('date', '>=', first)
      .where('date', '<=', last)
      .get();
    const attByDate: Record<string, any> = Object.fromEntries(attSnap.docs.map(d => [d.data().date, d.data()]));

    // ---- CHANGE #1: Only Approved leaves are considered ----
    const leavesSnap = await db.collection(LEAVE_COL)
      .where('empid', '==', empid)
      .where('approvalStatus', '==', 'Approved')
      .get();

    const rangeLeaves: Array<{ start: string; end: string; isHalf: boolean }> = [];
    let permissionCount = 0;

    leavesSnap.forEach(doc => {
      const l = doc.data();
      const type = String((l as any).type || '').toLowerCase();
      const sdStr = toISO((l as any).startDate || (l as any).selectDate || (l as any).date);
      const edStr = toISO((l as any).endDate   || (l as any).selectDate || (l as any).date || (l as any).startDate);

      if (type.includes('permission')) {
        if ((sdStr && sdStr >= first && sdStr <= last) ||
            (edStr && edStr >= first && edStr <= last)) {
          permissionCount += 1;
        }
        return;
      }
      if (!sdStr) return;

      const start = sdStr;
      const end   = edStr || sdStr;
      if (end < first || start > last) return;

      rangeLeaves.push({ start, end, isHalf: type.includes('half') });
    });

    const holidaySet = new Set<string>(HOLIDAYS_SET);

    const dayStatuses: Record<string, string> = {};
    let present = 0, absent = 0, leave = 0, holiday = 0, weekOff = 0, halfDay = 0, late = 0, early = 0;

    const today = toYMD(new Date());
    const stopAt = (year === today.slice(0, 4) && month === today.slice(5, 7)) ? today : last;

    for (let d = 1; d <= daysInMonth(y, m); d++) {
      const ymd = `${year}-${month}-${pad2(d)}`;
      if (ymd > stopAt) continue;

      let status: string;

      if (holidaySet.has(ymd)) {
        status = 'Holiday'; holiday++;
      } else if (isSunday(ymd)) { // <— now IST-safe
        status = 'WeekOff'; weekOff++;
      } else {
        const rec = attByDate[ymd];

        // ---- CHANGE #2: Attendance (Present/HalfDay) overrides Leave ----
        if (rec && (rec as any).checkIn) {
          status = 'Present'; present++;
          if (cmpHHMM((rec as any).checkIn, shiftStart)) late++;
          if ((rec as any).checkOut && !cmpHHMM((rec as any).checkOut, shiftEnd)) early++;
          if (cmpHHMM((rec as any).checkIn, mid)) {
            status = 'HalfDay';
            halfDay++;
            present--;
          }
        } else {
          const lv = rangeLeaves.find(L => (L as any).start <= ymd && ymd <= (L as any).end);
          if (lv) {
            if ((lv as any).isHalf) { status = 'HalfDay'; halfDay++; }
            else                   { status = 'Leave';   leave++;   }
          } else {
            status = 'Absent'; absent++;
          }
        }
      }

      dayStatuses[ymd] = status;
    }

    return res.json({
      empid,
      month: `${year}-${month}`,
      shift: { group: (emp as any).shiftGroup, startTime: shiftStart, endTime: shiftEnd, midpoint: mid },
      dayStatuses,
      totals: { present, absent, leave, holiday, weekOff, halfDay },
      extras: { lateCheckin: late, earlyCheckout: early, permissionCount },
    });
  } catch (err: any) {
    console.error('getMonthView error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/* ============================== Approvals & My Requests ============================== */

const normalizeType = (s: any) => {
  const t = normStr(s).toLowerCase().replace(/\s+/g, ' ');
  if (!t || t === 'all' || t === 'type') return 'all';
  if (t.includes('other') && t.includes('location')) return 'attendance:other_location'; // NEW
  if (t.includes('late')  && t.includes('check') && t.includes('in'))  return 'late check in';
  if (t.includes('early') && t.includes('check') && t.includes('out')) return 'early check out';
  if (t.includes('late')  && t.includes('check') && t.includes('out')) return 'late check out';
  if (t.includes('permission'))                 return 'permission';
  if (t.includes('over') && t.includes('time')) return 'over time';
  if (t.includes('half') && t.includes('day'))  return 'half day leave';
  if (t.includes('comp') && t.includes('off'))  return 'comp off';
  if (t.includes('leave'))                      return 'leave type';
  return t;
};
const mapLeaveType = (txt: any) => {
  const t = normStr(txt).toLowerCase();
  if (t.includes('permission')) return 'Permission';
  if (t.includes('over') && t.includes('time')) return 'Over Time';
  if (t.includes('half') && t.includes('day'))  return 'Half Day Leave';
  if (t.includes('comp') && t.includes('off'))  return 'Comp Off';
  return 'Leave Type';
};
const overlaps = (aStart?: string | null, aEnd?: string | null, bStart?: string | null, bEnd?: string | null) => {
  if (!aStart && !aEnd) return true;
  const A1 = aStart || '0000-01-01';
  const A2 = aEnd   || '9999-12-31';
  const B1 = bStart || bEnd || '';
  const B2 = bEnd   || bStart || '';
  if (!B1) return true;
  return (B1 <= A2) && (B2 >= A1);
};

/** GET /api/attendance/approvals */
export const listApprovalRequests = async (req: Request, res: Response) => {
  try {
    const typeFilter   = normalizeType(req.query.type || 'All');
    const statusRaw    = normStr(req.query.status || 'Pending');
    const statusWanted = statusRaw.toLowerCase(); // pending|approved|rejected|all
    const start        = (String(req.query.start || '').slice(0, 10)) || null;
    const end          = (String(req.query.end   || '').slice(0, 10)) || null;

    const empSnap = await db.collection(EMP_COL).get();
    const empById: Record<string, any> = Object.fromEntries(empSnap.docs.map(d => [d.data().empid, d.data()]));
    const shiftSnap = await db.collection(SHIFT_COL).get();
    const shiftByGroup: Record<string, any> = Object.fromEntries(shiftSnap.docs.map(d => [d.data().group, d.data()]));

    const out: any[] = [];

    // ---------- NEW: Other Location tab ----------
    if (typeFilter.includes('other_location')) {
      let ref: FirebaseFirestore.Query = db.collection(OTHER_LOC_COL);
      if (statusWanted !== 'all') ref = ref.where('approvalStatus', '==', statusRaw);
      if (start) ref = ref.where('date', '>=', start);
      if (end)   ref = ref.where('date', '<=', end);

      const oSnap = await ref.get();
      oSnap.forEach(d => {
        const e = d.data() as any;
        const emp = empById[e.empid] || {};
        out.push({
          source: 'attendance',
          requestId: d.id,
          type: 'Other Location',
          empid: e.empid,
          name: emp.name || e.name || '',
          department: emp.dept || emp.department || '',
          shift: emp.shift || (shiftByGroup[emp.shiftGroup || '']?.shift) || null,
          shiftGroup: emp.shiftGroup || '',
          requestTime: e.time || '',
          requestDate: e.date || '',
          reason: e.otherLocation || '-',
          location: e.branchName || e.location || '-',
          latitude: e.latitude ?? null,
          longitude: e.longitude ?? null,
          expectedLatitude: e.expectedLatitude ?? null,
          expectedLongitude: e.expectedLongitude ?? null,
          expectedRadius: e.expectedRadius ?? null,
          distanceFromBranch: e.distanceFromBranch ?? null,
          withinRadius: e.withinRadius ?? null,
          status: e.approvalStatus || 'Pending',
        });
      });

      out.sort((a, b) =>
        String(b.requestDate || '').localeCompare(String(a.requestDate || '')) ||
        String(b.requestTime || '').localeCompare(String(a.requestTime || ''))
      );
      return res.json(out);
    }

    // ---------- Attendance (late/early) ----------
    let attRef: FirebaseFirestore.Query = db.collection(ATT_COL);
    if (statusWanted !== 'all') attRef = attRef.where('approvalStatus', '==', statusRaw);
    if (start) attRef = attRef.where('date', '>=', start);
    if (end)   attRef = attRef.where('date', '<=', end);

    const attSnap = await attRef.get();
    attSnap.forEach(doc => {
      const a = doc.data() as any;
      const emp = empById[a.empid] || {};
      const shift = shiftByGroup[emp.shiftGroup] || {};
      const startTime = shift.startTime || '09:00';
      const endTime   = shift.endTime   || '18:00';

      let subType: string | null = null;
      if (a.checkIn  && a.checkIn  > startTime) subType = 'Late check in';
      if (a.checkOut && a.checkOut < endTime)   subType = 'Early check out';
      else if (a.checkOut && a.checkOut > endTime) subType = 'Late check out';
      if (!subType) return;
      if (typeFilter !== 'all' && normalizeType(subType) !== typeFilter) return;

      out.push({
        source: 'attendance',
        requestId: doc.id,
        type: subType,
        empid: a.empid,
        name: emp.name || a.name || '',
        department: emp.dept || emp.department || '',
        shift: emp.shift || shift.shift || null,
        shiftGroup: emp.shiftGroup || '',
        requestTime: subType === 'Late check in' ? (a.checkIn || '') : (a.checkOut || ''),
        requestDate: a.date,
        reason: a.reason || '-',
        location: a.location || '-',
        checkInLatitude: a.checkInLatitude ?? null,
        checkInLongitude: a.checkInLongitude ?? null,
        checkInAccuracy: a.checkInAccuracy ?? null,
        checkOutLatitude: a.checkOutLatitude ?? null,
        checkOutLongitude: a.checkOutLongitude ?? null,
        checkOutAccuracy: a.checkOutAccuracy ?? null,
        branchName: a.branchName ?? null,
        expectedLatitude: a.expectedLatitude ?? null,
        expectedLongitude: a.expectedLongitude ?? null,
        expectedRadius: a.expectedRadius ?? null,
        distanceFromBranch: a.distanceFromBranch ?? null,
        withinRadius: a.withinRadius ?? null,
        checkoutDistanceFromBranch: a.checkoutDistanceFromBranch ?? null,
        checkoutWithinRadius: a.checkoutWithinRadius ?? null,
        status: a.approvalStatus || 'Pending',
      });
    });

    // ---------- Leaves ----------
    const leaveSnap = await db.collection(LEAVE_COL).get();
    leaveSnap.forEach(doc => {
      const L = doc.data() as any;
      const emp = empById[L.empid] || {};

      const sNorm = normStr(L.approvalStatus ?? L.status ?? 'Pending').toLowerCase();
      if (statusWanted !== 'all' && sNorm !== statusWanted) return;

      const friendlyType = mapLeaveType(L.type);
      const dStart = toISO(L.startDate || L.date || L.selectDate);
      const dEnd   = toISO(L.endDate   || dStart);
      if (!overlaps(start, end, dStart, dEnd)) return;
      if (typeFilter !== 'all' && normalizeType(friendlyType) !== typeFilter) return;

      out.push({
        source: 'leaves',
        requestId: doc.id,
        type: friendlyType,
        empid: L.empid,
        name: emp.name || L.name || '',
        department: emp.dept || emp.department || L.department || '',
        shift: emp.shift || null,
        shiftGroup: emp.shiftGroup || '',
        requestTime: L.time || L.requestTime || '',
        requestDate: dStart || '',
        reason: L.reason || '-',
        location: L.location || '-',
        latitude: L.latitude || null,
        longitude: L.longitude || null,
        status: L.approvalStatus ?? L.status ?? 'Pending',
      });
    });

    out.sort((a, b) => String(b.requestDate || '').localeCompare(String(a.requestDate || '')));
    return res.json(out);
  } catch (err: any) {
    console.error('listApprovalRequests error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** Alias used by your router for /api/attendance/approvals */
export const listApprovals = (req: Request, res: Response) => listApprovalRequests(req, res);

/** POST /api/attendance/approvals/decision */
export const decideApproval = async (req: Request, res: Response) => {
  try {
    const { source, attendanceId, leaveId, empid, date, status, remarks, id, requestId } = req.body || {};
    const clean = normStr(status);
    if (!['Approved', 'Rejected'].includes(clean)) {
      return res.status(400).json({ error: 'status must be Approved or Rejected' });
    }
    if (!source || !['attendance', 'leaves'].includes(source)) {
      return res.status(400).json({ error: 'source must be attendance or leaves' });
    }

    // Try to resolve a generic id first (may belong to attendance OR otherLocation)
    const genericId = String(id || requestId || '');

    if (source === 'attendance') {
      // If an explicit attendanceId is supplied, use it
      if (attendanceId) {
        await db.collection(ATT_COL).doc(String(attendanceId)).update({
          approvalStatus: clean,
          decisionBy: getReqEmpId(req),
          decisionAt: admin.firestore.FieldValue.serverTimestamp(),
          decisionRemarks: remarks || null,
        });
        return res.json({ message: `Attendance ${clean.toLowerCase()} successfully` });
      }

      // If we have a generic id, try attendance first, then otherLocation
      if (genericId) {
        const attRef = db.collection(ATT_COL).doc(genericId);
        const attDoc = await attRef.get();
        if (attDoc.exists) {
          await attRef.update({
            approvalStatus: clean,
            decisionBy: getReqEmpId(req),
            decisionAt: admin.firestore.FieldValue.serverTimestamp(),
            decisionRemarks: remarks || null,
          });
          return res.json({ message: `Attendance ${clean.toLowerCase()} successfully` });
        }

        const olRef = db.collection(OTHER_LOC_COL).doc(genericId);
        const olDoc = await olRef.get();
        if (olDoc.exists) {
          await olRef.update({
            approvalStatus: clean,
            decisionBy: getReqEmpId(req),
            decisionAt: admin.firestore.FieldValue.serverTimestamp(),
            decisionRemarks: remarks || null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return res.json({ message: `Other-location ${clean.toLowerCase()} successfully` });
        }
      }

      // Finally, try by (empid,date)
      if (empid && date) {
        const q = await db.collection(ATT_COL)
          .where('empid', '==', empid)
          .where('date', '==', date)
          .limit(1).get();
        if (q.empty) return res.status(404).json({ error: 'Attendance record not found' });

        await q.docs[0].ref.update({
          approvalStatus: clean,
          decisionBy: getReqEmpId(req),
          decisionAt: admin.firestore.FieldValue.serverTimestamp(),
          decisionRemarks: remarks || null,
        });
        return res.json({ message: `Attendance ${clean.toLowerCase()} successfully` });
      }

      return res.status(400).json({ error: 'attendanceId or (id/requestId) or (empid & date) required' });
    }

    // Leaves
    if (!leaveId) return res.status(400).json({ error: 'leaveId required' });
    await db.collection(LEAVE_COL).doc(String(leaveId)).update({
      approvalStatus: clean,
      decisionBy: getReqEmpId(req),
      decisionAt: admin.firestore.FieldValue.serverTimestamp(),
      decisionRemarks: remarks || null,
    });
    return res.json({ message: `Leave ${clean.toLowerCase()} successfully` });
  } catch (err: any) {
    console.error('decideApproval error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/* ============================== NEW: Other Location routes (optional) ============================== */

/** GET /api/attendance/other-location?status=Pending|Approved|Rejected|All&start=YYYY-MM-DD&end=YYYY-MM-DD */
export const listOtherLocationEvents = async (req: Request, res: Response) => {
  try {
    const statusRaw = normStr(req.query.status || 'Pending');
    const want = statusRaw.toLowerCase(); // pending|approved|rejected|all
    const start = (String(req.query.start || '').slice(0, 10)) || null;
    const end   = (String(req.query.end   || '').slice(0, 10)) || null;

    let ref: FirebaseFirestore.Query = db.collection(OTHER_LOC_COL);
    if (want !== 'all') ref = ref.where('approvalStatus', '==', statusRaw);
    if (start) ref = ref.where('date', '>=', start);
    if (end)   ref = ref.where('date', '<=', end);

    const snap = await ref.get();
    const rows = snap.docs.map(d => ({ id: d.id, ...d.data() }));

    rows.sort((a: any, b: any) =>
      String(b.date || '').localeCompare(String(a.date || '')) ||
      String(b.time || '').localeCompare(String(a.time || ''))
    );

    return res.json(rows);
  } catch (err: any) {
    console.error('listOtherLocationEvents error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** POST /api/attendance/other-location/decision { id, status: 'Approved'|'Rejected', remarks? } */
export const decideOtherLocationEvent = async (req: Request, res: Response) => {
  try {
    const { id, status, remarks } = req.body || {};
    const clean = normStr(status);
    if (!id) return res.status(400).json({ error: 'id required' });
    if (!['Approved', 'Rejected'].includes(clean)) {
      return res.status(400).json({ error: 'status must be Approved or Rejected' });
    }

    await db.collection(OTHER_LOC_COL).doc(String(id)).update({
      approvalStatus: clean,
      decisionBy: getReqEmpId(req),
      decisionAt: admin.firestore.FieldValue.serverTimestamp(),
      decisionRemarks: remarks || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.json({ message: `Other-location ${clean.toLowerCase()} successfully` });
  } catch (err: any) {
    console.error('decideOtherLocationEvent error:', err);
    return res.status(500).json({ error: err.message });
  }
};

/** GET /api/attendance/my-requests */
export const listMyRequests = async (req: Request, res: Response) => {
  try {
    const empid = getReqEmpId(req);
    if (!empid) return res.status(401).json({ message: 'Unauthorized' });

    const statusQ = normStr(req.query.status || 'All');
    const wantStatus = statusQ.toLowerCase();
    const start = (String(req.query.start || '').slice(0, 10));
    const end   = (String(req.query.end   || '').slice(0, 10));
    const singleDay = !!(start && end && start === end);

    const shiftsSnap = await db.collection(SHIFT_COL).get();
    const shiftByGroup: Record<string, any> = {};
    shiftsSnap.forEach(d => { const s = d.data(); (shiftByGroup as any)[(s as any).group] = s; });

    let emp: any = null;
    const eSnap = await db.collection(EMP_COL).where('empid', '==', empid).limit(1).get();
    if (!eSnap.empty) emp = eSnap.docs[0].data();

    const out: any[] = [];

    let attRef: FirebaseFirestore.Query = db.collection(ATT_COL).where('empid', '==', empid);
    if (start) attRef = attRef.where('date', '>=', start);
    if (end)   attRef = attRef.where('date', '<=', end);
    const attSnap = await attRef.get();

    attSnap.forEach(doc => {
      const a = doc.data() as any;

      const sNorm = normStr(a.approvalStatus || 'Pending').toLowerCase();
      if (wantStatus !== 'all' && sNorm !== wantStatus) return;
      if (singleDay && a.date !== start) return;

      const shift = shiftByGroup[emp?.shiftGroup] || {};
      const startTime = shift.startTime || '09:00';
      const endTime   = shift.endTime   || '18:00';

      let subType: string | null = null;
      if (a.checkIn  && a.checkIn  > startTime) subType = 'Late check in';
      else if (a.checkOut && a.checkOut < endTime) subType = 'Early check out';
      else if (a.checkOut && a.checkOut > endTime) subType = 'Late check out';

      out.push({
        source: 'attendance',
        requestId: doc.id,
        type: subType || 'Attendance',
        empid: a.empid,
        name: a.name || '',
        requestDate: a.date,
        requestTime:
          subType === 'Late check in' ? (a.checkIn || '') :
          (subType === 'Late check out' || subType === 'Early check out') ? (a.checkOut || '') : '',
        reason: a.reason || '-',
        location: a.location || '-',
        checkInLatitude: a.checkInLatitude ?? null,
        checkInLongitude: a.checkInLongitude ?? null,
        checkInAccuracy: a.checkInAccuracy ?? null,
        checkOutLatitude: a.checkOutLatitude ?? null,
        checkOutLongitude: a.checkOutLongitude ?? null,
        checkOutAccuracy: a.checkOutAccuracy ?? null,
        branchName: a.branchName ?? null,
        expectedLatitude: a.expectedLatitude ?? null,
        expectedLongitude: a.expectedLongitude ?? null,
        expectedRadius: a.expectedRadius ?? null,
        distanceFromBranch: a.distanceFromBranch ?? null,
        withinRadius: a.withinRadius ?? null,
        checkoutDistanceFromBranch: a.checkoutDistanceFromBranch ?? null,
        checkoutWithinRadius: a.checkoutWithinRadius ?? null,
        status: a.approvalStatus || 'Pending',
      });
    });

    const leaveSnap = await db.collection(LEAVE_COL).where('empid', '==', empid).get();
    leaveSnap.forEach(doc => {
      const L = doc.data() as any;
      const sNorm = normStr(L.approvalStatus ?? L.status ?? 'Pending').toLowerCase();
      if (wantStatus !== 'all' && sNorm !== wantStatus) return;

      const dStart = toISO(L.startDate || L.date || L.selectDate);
      const dEnd   = toISO(L.endDate   || dStart);

      if (singleDay) {
        if (!(dStart && start >= dStart && start <= (dEnd || dStart))) return;
      } else {
        if (start && dEnd   && dEnd   < start) return;
        if (end   && dStart && dStart > end)   return;
      }

      out.push({
        source: 'leaves',
        requestId: doc.id,
        type: mapLeaveType(L.type),
        empid: L.empid,
        name: L.name || '',
        requestDate: dStart || '',
        requestTime: L.time || '',
        reason: L.reason || '-',
        location: L.location || '-',
        latitude: L.latitude || null,
        longitude: L.longitude || null,
        status: L.approvalStatus ?? L.status ?? 'Pending',
      });
    });

    out.sort((a, b) => String(b.requestDate || '').localeCompare(String(a.requestDate || '')));
    return res.json(out);
  } catch (err: any) {
    console.error('listMyRequests error:', err);
    return res.status(500).json({ error: err.message });
  }
};
