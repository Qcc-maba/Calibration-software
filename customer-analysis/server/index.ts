import "dotenv/config"; // load the unified .env before anything reads process.env
import express, { type Request, Response, NextFunction } from "express";
import compression from "compression";
import { registerRoutes } from "./routes";
import { serveStatic } from "./static";
import { createServer } from "http";
import { db } from "./db";
import { sql } from "drizzle-orm";

const app = express();
const httpServer = createServer(app);

declare module "http" {
  interface IncomingMessage {
    rawBody: unknown;
  }
}

app.use(compression());
app.use(
  express.json({
    limit: '50mb',
    verify: (req, _res, buf) => {
      req.rawBody = buf;
    },
  }),
);

app.use(express.urlencoded({ extended: false, limit: '50mb' }));

// ─── Remote access guard ──────────────────────────────────────────────────────
// The dashboard has no login of its own and exposes 28 write endpoints
// (admin/bulk-import-*, admin/export-db, sync/*, …). It was only ever safe
// because Windows Firewall kept it unreachable. Once the port is opened to a
// colleague that is no longer true, so anything arriving from another machine
// must authenticate, and by default may only read.
//
//   DASHBOARD_USER / DASHBOARD_PASSWORD  — credentials for remote viewers
//   ALLOW_REMOTE_WRITES=true             — opt in to remote writes (off by default)
//
// Requests from this machine are untouched, so local use and the sync scripts
// behave exactly as before. Fail-safe: with no password set, remote access is
// refused rather than allowed.
const AUTH_USER = process.env.DASHBOARD_USER || '';
const AUTH_PASS = process.env.DASHBOARD_PASSWORD || '';
const ALLOW_REMOTE_WRITES = process.env.ALLOW_REMOTE_WRITES === 'true';
const READ_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

function isLocalRequest(req: Request): boolean {
  const ip = (req.ip || req.socket.remoteAddress || '').replace(/^::ffff:/, '');
  return ip === '127.0.0.1' || ip === '::1' || ip === '';
}

/** timing-safe-ish compare that does not leak length via early exit */
function sameSecret(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

app.use((req: Request, res: Response, next: NextFunction) => {
  if (isLocalRequest(req)) return next();

  if (!AUTH_PASS) {
    log(`blocked remote request from ${req.ip} — DASHBOARD_PASSWORD is not set`, 'auth');
    return res.status(403).json({
      error: 'Remote access is disabled. Set DASHBOARD_USER and DASHBOARD_PASSWORD to enable it.',
    });
  }

  const header = req.headers.authorization || '';
  const [scheme, encoded] = header.split(' ');
  let ok = false;
  if (scheme === 'Basic' && encoded) {
    const [user, ...rest] = Buffer.from(encoded, 'base64').toString('utf8').split(':');
    ok = sameSecret(user || '', AUTH_USER) && sameSecret(rest.join(':'), AUTH_PASS);
  }
  if (!ok) {
    res.set('WWW-Authenticate', 'Basic realm="QCC Analytics", charset="UTF-8"');
    return res.status(401).json({ error: 'Authentication required' });
  }

  if (!READ_METHODS.has(req.method) && !ALLOW_REMOTE_WRITES) {
    log(`blocked remote ${req.method} ${req.path} from ${req.ip} — read-only mode`, 'auth');
    return res.status(403).json({ error: 'This dashboard is shared read-only.' });
  }

  next();
});

export function log(message: string, source = "express") {
  const formattedTime = new Date().toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    second: "2-digit",
    hour12: true,
  });

  console.log(`${formattedTime} [${source}] ${message}`);
}

app.use((req, res, next) => {
  const start = Date.now();
  const path = req.path;
  let capturedJsonResponse: Record<string, any> | undefined = undefined;

  const originalResJson = res.json;
  res.json = function (bodyJson, ...args) {
    capturedJsonResponse = bodyJson;
    return originalResJson.apply(res, [bodyJson, ...args]);
  };

  res.on("finish", () => {
    const duration = Date.now() - start;
    if (path.startsWith("/api")) {
      let logLine = `${req.method} ${path} ${res.statusCode} in ${duration}ms`;
      if (capturedJsonResponse) {
        logLine += ` :: ${JSON.stringify(capturedJsonResponse)}`;
      }

      log(logLine);
    }
  });

  next();
});

(async () => {
  // Run schema migrations on startup
  try {
    await db.execute(sql`ALTER TABLE company_calibration_alerts ADD COLUMN IF NOT EXISTS sync_id VARCHAR`);
    console.log('[MIGRATION] company_calibration_alerts.sync_id column ready');
  } catch (e: any) {
    console.warn('[MIGRATION] sync_id column migration skipped:', e.message);
  }

  await registerRoutes(httpServer, app);

  app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
    const status = err.status || err.statusCode || 500;
    const message = err.message || "Internal Server Error";

    res.status(status).json({ message });
    throw err;
  });

  // importantly only setup vite in development and after
  // setting up all the other routes so the catch-all route
  // doesn't interfere with the other routes
  if (process.env.NODE_ENV === "production") {
    serveStatic(app);
  } else {
    const { setupVite } = await import("./vite");
    await setupVite(httpServer, app);
  }

  // ALWAYS serve the app on the port specified in the environment variable PORT
  // Other ports are firewalled. Default to 5000 if not specified.
  // this serves both the API and the client.
  // It is the only port that is not firewalled.
  const port = parseInt(process.env.PORT || "5000", 10);
  // reusePort is a Linux-only socket option; it throws ENOTSUP on Windows/macOS.
  const listenOptions: { port: number; host: string; reusePort?: boolean } = {
    port,
    host: "0.0.0.0",
    ...(process.platform === "linux" ? { reusePort: true } : {}),
  };
  httpServer.listen(listenOptions, () => {
    log(`serving on port ${port}`);
  });
})();
