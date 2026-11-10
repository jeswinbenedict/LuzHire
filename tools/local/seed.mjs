// Offline demo data that lives outside Postgres: sign-in records (with the
// same ids as the profiles in supabase/seed.sql) and resume PDFs in Storage.
import { mkdirSync, writeFileSync } from 'node:fs';
import { randomBytes, scryptSync } from 'node:crypto';
import { DATA_DIR, USERS_FILE } from './config.mjs';

/**
 * Password of every demo account. A test value for this local demo only:
 * these accounts exist nowhere but the local database (docs/OFFLINE_DEMO.md).
 */
export const DEMO_PASSWORD = 'LuzHire-Demo-2026';

export const DEMO_ACCOUNTS = [
  { uid: 'demo-tom', email: 'tom@luzhire.local', name: 'Tom', role: 'candidate' },
  { uid: 'demo-lisa', email: 'lisa@luzhire.local', name: 'Lisa Immanuel', role: 'employer' },
  { uid: 'demo-jechu', email: 'jechu@luzhire.local', name: 'Jechu Emmanuel', role: 'admin' },
  // Fictional extras from the seed, for a fuller demo.
  { uid: 'seed-candidate', email: 'candidate@luzhire.dev', name: 'Asha Verma', role: 'candidate' },
  { uid: 'seed-employer', email: 'employer@luzhire.dev', name: 'Meera Nair', role: 'employer' },
];

const hash = (password) => {
  const salt = randomBytes(16).toString('hex');
  return `${salt}:${scryptSync(password, salt, 32).toString('hex')}`;
};

/** Writes users.json in the format of api/_lib/local-identity.ts. */
export async function seedAccounts() {
  mkdirSync(DATA_DIR, { recursive: true });
  const users = DEMO_ACCOUNTS.map((a) => ({
    uid: a.uid,
    email: a.email,
    displayName: a.name,
    passwordHash: hash(DEMO_PASSWORD),
    emailVerified: true,
    disabled: false,
    claims: { role: 'authenticated', app_role: a.role },
    validAfter: 0,
  }));
  writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
  console.log(`  ${users.length} accounts → ${USERS_FILE}`);
}

/** A one-page PDF résumé (plain text, standard Helvetica). */
function resumePdf(lines) {
  const esc = (s) => s.replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');
  const text = lines
    .map((l, i) => `BT /F1 ${i === 0 ? 20 : 11} Tf 60 ${770 - i * 22} Td (${esc(l)}) Tj ET`)
    .join('\n');
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    `<< /Length ${Buffer.byteLength(text)} >>\nstream\n${text}\nendstream`,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  let pdf = '%PDF-1.4\n';
  const offsets = [];
  objects.forEach((o, i) => {
    offsets.push(Buffer.byteLength(pdf));
    pdf += `${i + 1} 0 obj\n${o}\nendobj\n`;
  });
  const xref = Buffer.byteLength(pdf);
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  pdf += offsets.map((o) => `${String(o).padStart(10, '0')} 00000 n \n`).join('');
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf);
}

const RESUMES = [
  {
    path: 'demo-tom/tom-resume.pdf',
    lines: [
      'Tom', 'Chennai, India  |  tom@luzhire.local', '',
      'Education: B.E. Computer Science and Engineering, Anna University (2022-2026), 8.4 CGPA',
      'Experience: Software Engineering Intern, Bluefin Systems (May-Jul 2025)',
      '  Built a Flutter dashboard and Node.js endpoints; wrote widget and API tests.',
      'Skills: Flutter, Dart, Node.js, PostgreSQL, REST APIs, Git',
      'Projects: Campus events app (Flutter + Firebase); expense tracker API (Node.js)',
    ],
  },
  {
    path: 'seed-candidate/asha-verma-resume.pdf',
    lines: [
      'Asha Verma', 'Bengaluru, India  |  candidate@luzhire.dev', '',
      'Education: Integrated M.Tech, Computer Science and Engineering, VIT-AP University',
      'Experience: Flutter Intern, Pixelforge Studio (May-Jul 2025)',
      'Skills: Flutter, Dart, Firebase, Git',
    ],
  },
];

/** Uploads the demo résumés to the private "resumes" bucket. */
export async function uploadResumes(env) {
  for (const r of RESUMES) {
    const res = await fetch(`${env.API_URL}/storage/v1/object/resumes/${r.path}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.SERVICE_ROLE_KEY}`,
        apikey: env.SERVICE_ROLE_KEY,
        'Content-Type': 'application/pdf',
        'x-upsert': 'true',
      },
      body: resumePdf(r.lines),
    });
    if (!res.ok) throw new Error(`Uploading ${r.path} failed: ${res.status} ${await res.text()}`);
    console.log(`  uploaded ${r.path}`);
  }
}
