import bcrypt from "bcryptjs";

const plain = "Suja25@serv";
const hash  = "$2a$10$7MGViJTEUD/pktpu/3fYX.eyjruM1aYzPW1YzymQG51uIl7vkMv1C";

async function check() {
  const ok = await bcrypt.compare(plain, hash);
  console.log("Password match:", ok);
}

check();
