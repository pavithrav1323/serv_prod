import { getApps, initializeApp, applicationDefault, cert, AppOptions } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { getStorage } from 'firebase-admin/storage';

// NOTE:
// - Do NOT use firebase-functions Params here (no defineString / .value() at module load).
// - Rely on ADC in production. In local dev, use serviceAccountKey.json if present.

let appInitialized = false;

if (!getApps().length) {
  let options: AppOptions | undefined;

  // Prefer explicit service account when available locally
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const serviceAccount = require('../../serviceAccountKey.json');
    options = {
      credential: cert(serviceAccount),
      storageBucket:
        process.env.APP_STORAGE_BUCKET ||
        (process.env.GCLOUD_PROJECT ? `${process.env.GCLOUD_PROJECT}.appspot.com` : undefined),
    };
  } catch {
    // Fall back to Application Default Credentials (Functions/Cloud Run)
    options = {
      credential: applicationDefault(),
      storageBucket:
        process.env.APP_STORAGE_BUCKET ||
        (process.env.GCLOUD_PROJECT ? `${process.env.GCLOUD_PROJECT}.appspot.com` : undefined),
    };
  }

  initializeApp(options);
  appInitialized = true;
}

// Expose Admin services
export const db = getFirestore();
export const auth = getAuth();
export const storage = getStorage();

// Firestore recommended setting to ignore undefined fields
db.settings({ ignoreUndefinedProperties: true });

// Helpful log in dev
if (appInitialized) {
  // eslint-disable-next-line no-console
  console.log('[firebase] Admin initialized. Bucket:', storage.bucket().name);
}

export default { db, auth, storage };
