// helpers/time.ts (or inline where you save)
export function nowUtcIst() {
    const now = new Date();                 // the actual instant
    const atMs = now.getTime();             // epoch (best for sorting)
    const ts   = now.toISOString();         // UTC ISO
  
    // Human-readable IST string like "20-09-2025 09:05:11 AM"
    const tsIST = new Intl.DateTimeFormat('en-IN', {
      timeZone: 'Asia/Kolkata',
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit',
      hour12: true,
    }).format(now);
  
    return { now, atMs, ts, tsIST };
  }
  