/**
 * import_users.ts
 * Run once to bulk-create Firebase Authentication users from a JSON list.
 */

import * as admin from "firebase-admin";
import * as fs from "fs";

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(
    require("../serviceAccountKey.json") // adjust path if needed
  ),
});

interface UserEntry {
  email: string;
  password: string;
}

async function importUsers() {
  try {
    const users: UserEntry[] = JSON.parse(fs.readFileSync("./users.json", "utf8"));

    for (const u of users) {
      try {
        await admin.auth().createUser({
          email: u.email,
          password: u.password,
        });
        console.log(`✅ Added: ${u.email}`);
      } catch (err: any) {
        console.error(`❌ Error adding ${u.email} - ${err.message}`);
      }
    }

    console.log("\n🎉 Import complete!");
    process.exit(0);
  } catch (err) {
    console.error("Failed to read or process users.json:", err);
  }
}

importUsers();
