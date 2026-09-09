import { build as esbuild } from "esbuild";
import { build as viteBuild } from "vite";
import { rm, readFile } from "fs/promises";
import { execSync } from "child_process";

// Build stamp, compiled into both halves and shown in the UI. Without it there
// is no way to tell from the outside whether a deploy actually took - we spent
// an afternoon guessing exactly that.
function buildId(): string {
  const now = new Date();
  const pad = (n: number) => String(n).padStart(2, "0");
  const when =
    `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}` +
    ` ${pad(now.getHours())}:${pad(now.getMinutes())}`;
  let sha = "";
  try {
    sha = execSync("git rev-parse --short HEAD", { encoding: "utf-8" }).trim();
  } catch {
    // not a git checkout, or git is not on PATH - the timestamp alone still identifies the build
  }
  return sha ? `${when} (${sha})` : when;
}

// server deps to bundle to reduce openat(2) syscalls
// which helps cold start times
// הפריסה מחליפה את dist בלבד ולא מריצה npm install על מכונת השירות, ולכן כל
// תלות חדשה של השרת חייבת להיות כאן - אחרת השרת נופל בעלייה על MODULE_NOT_FOUND.
// fuse.js / xlsx / @anthropic-ai/sdk נוספו עם מודול התמחור (server/pricing),
// ו-compression / exceljs נוספו כדי שה-bundle יהיה עצמאי לחלוטין: כך אפשר
// לפרוס אותו למכונה שאין בה node_modules מתאימים, בלי להסתמך על מה שכבר מותקן שם.
const allowlist = [
  "@anthropic-ai/sdk",
  "@google/generative-ai",
  "axios",
  "compression",
  "exceljs",
  "fuse.js",
  "connect-pg-simple",
  "cors",
  "date-fns",
  "dotenv",
  "drizzle-orm",
  "drizzle-zod",
  "express",
  "express-rate-limit",
  "express-session",
  "jsonwebtoken",
  "memorystore",
  "mssql",
  "multer",
  "nanoid",
  "nodemailer",
  "openai",
  "passport",
  "passport-local",
  "pg",
  "stripe",
  "uuid",
  "ws",
  "xlsx",
  "zod",
  "zod-validation-error",
];

async function buildAll() {
  await rm("dist", { recursive: true, force: true });

  const BUILD_ID = buildId();
  console.log(`build id: ${BUILD_ID}`);

  console.log("building client...");
  await viteBuild({ define: { __BUILD_ID__: JSON.stringify(BUILD_ID) } });

  console.log("building server...");
  const pkg = JSON.parse(await readFile("package.json", "utf-8"));
  const allDeps = [
    ...Object.keys(pkg.dependencies || {}),
    ...Object.keys(pkg.devDependencies || {}),
  ];
  const externals = allDeps.filter((dep) => !allowlist.includes(dep));

  await esbuild({
    entryPoints: ["server/index.ts"],
    platform: "node",
    bundle: true,
    format: "cjs",
    outfile: "dist/index.cjs",
    define: {
      "process.env.NODE_ENV": '"production"',
      __BUILD_ID__: JSON.stringify(BUILD_ID),
    },
    minify: true,
    external: externals,
    logLevel: "info",
  });
}

buildAll().catch((err) => {
  console.error(err);
  process.exit(1);
});
