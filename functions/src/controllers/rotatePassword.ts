import * as bcrypt from 'bcryptjs';
import { Firestore, Timestamp } from 'firebase-admin/firestore';

type RotationSource = 'firebase_reset' | 'self_change' | 'admin_set' | 'migrated';

interface RotateOpts {
  db: Firestore;
  userId: string;
  oldHash?: string | null;
  newPlainPassword: string;
  source: RotationSource;
  keepLast?: number;
}

export async function rotatePassword(opts: RotateOpts) {
  const { db, userId, oldHash, newPlainPassword, source, keepLast = 5 } = opts;

  const userRef = db.collection('users').doc(userId);
  const histCol = userRef.collection('password_history');

  await db.runTransaction(async (tx) => {
    const now = Timestamp.now();

    // 1) Expire old hash
    if (oldHash) {
      const active = await histCol
        .where('hash', '==', oldHash)
        .where('status', '==', 'active')
        .limit(1)
        .get();

      if (!active.empty) {
        tx.update(active.docs[0].ref, { status: 'expired', expiredAt: now });
      } else {
        const hdoc = histCol.doc();
        tx.set(hdoc, {
          hash: oldHash,
          status: 'expired',
          changedAt: now,
          expiredAt: now,
          source: 'migrated',
          version: now.toMillis(),
        });
      }
    }

    // 2) Create new active hash
    const newHash = await bcrypt.hash(newPlainPassword, 10);
    const newDoc = histCol.doc();
    tx.set(newDoc, {
      hash: newHash,
      status: 'active',
      changedAt: now,
      expiredAt: null,
      source,
      version: now.toMillis(),
    });

    // 3) Update user document
    tx.set(
      userRef,
      {
        password: newHash,
        passwordHash: newHash,
        hashedPassword: newHash,
        authSource: 'firebase',
        lastPasswordChangedAt: now,
        updatedAt: now,
      },
      { merge: true }
    );

    // 4) Keep last N records only
    const histSnap = await histCol.orderBy('changedAt', 'desc').get();
    const toDelete = histSnap.docs.slice(keepLast);
    for (const d of toDelete) tx.delete(d.ref);
  });
}
