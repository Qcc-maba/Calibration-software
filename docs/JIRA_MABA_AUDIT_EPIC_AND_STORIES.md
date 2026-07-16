# Jira Backlog — MABA Audit Remediation

**Purpose:** Copy-paste into Jira or use as a CSV/import source.  
**Language:** English (Epic, Stories, AC, Tasks).  
**Source:** MABA — Architecture Audit (Industrial Calibration Management System).

---

## How to use in Jira

1. Create **one Epic** using section [Epic](#epic-maba--security--architecture-remediation-audit-follow-up).
2. For each **User Story**, create a Story issue, link it to the Epic (`Epic Link` / parent).
3. Create **Sub-tasks** (or Tasks linked with “implements” / parent) from the **Tasks** list under each story.
4. Set **Priority** from the story header (P0 / P1 / P2 / P3).

---

## Epic: MABA — Security & Architecture Remediation (Audit follow-up)

| Field | Content |
|-------|---------|
| **Epic Name / Summary** | MABA — Security & Architecture Remediation (Audit follow-up) |
| **Epic Type** | Epic |
| **Description** | Remediate findings from the MABA architecture and security audit of the Industrial Calibration Management System. The application stack includes Next.js, React, TypeScript, tRPC, Prisma (SQL Server), and AWS S3. The audit identified critical gaps: unauthenticated tRPC procedures, forgeable client-side session cookies, client-only RBAC, password exposure, SQL injection risks via raw SQL string building, unrestricted S3 operations, and missing server-side ownership checks across modules (users, orders, devices, sensors, calendars, equipment, cars, customers, AWS, master devices, contact info, etc.). This epic tracks phased work to align the product with defense-in-depth: verified identity on the server, least privilege, safe data access, secure file handling, and operational hardening. |
| **Business outcome** | Protect customer and operational data, prevent unauthorized calibration and order changes, meet organizational security expectations, and reduce incident and compliance risk. |
| **Success criteria (Epic)** | (1) No anonymous access to protected tRPC procedures. (2) No user-input string concatenation into SQL for dynamic queries. (3) S3 operations require authentication, authorization, and validated inputs. (4) Sensitive mutations use server-derived user identity for audit. (5) Documented permission mapping for major procedures. |

**Suggested labels:** `security`, `audit`, `maba`, `backend`, `trpc`  
**Suggested components:** `api`, `auth`, `infra`, `frontend` (as applicable)

---

# User Stories (with Acceptance Criteria & Tasks)

---

## US-01 — Server-side authentication & `protectedProcedure` (P0)

**Summary:** Implement verified server session (JWT) and `protectedProcedure` for all tRPC routes except explicit public endpoints.

**Story:**  
As a **security stakeholder**,  
I want **every tRPC procedure to run only after the server verifies the caller’s identity**,  
So that **the API cannot be invoked anonymously or with a forged client identity**.

**Background (from audit):**  
`createTRPCContext` does not extract user identity; only `publicProcedure` exists; all routers use `publicProcedure`; no JWT/session library on the server; tRPC route applies no auth middleware.

**Acceptance criteria**

1. Dependencies added: JWT signing/verification (e.g. `jose`) and password hashing library (e.g. `bcryptjs`) with types as needed.
2. Environment variable `SESSION_SECRET` (or equivalent) is required in production; documented in deployment docs.
3. New module (e.g. `src/server/auth/session.ts`) implements: mint signed session token on successful sign-in; `verifySession` from cookies/headers; clear invalid/expired session behavior.
4. Session cookie is **HttpOnly**, **Secure** (in production), **SameSite** appropriate (e.g. `Lax`); not a plain JSON cookie writable from client JS.
5. `createTRPCContext` attaches `ctx.user: { id, roles, email } | null` after verification.
6. `protectedProcedure` (or equivalent middleware) returns `UNAUTHORIZED` when `ctx.user` is null.
7. All routers migrated from `publicProcedure` to `protectedProcedure` except an explicit allowlist (e.g. `signIn`, and `getAllEmails` only if product still requires it public — document decision).
8. Client-side writes of forgeable `MABA_USER` (or equivalent) removed; sign-in response sets session via server.
9. Optional: `whoami` (or session query) for UI hydration from server truth.

**Definition of Done**

- [ ] Manual test: unauthenticated `curl`/client call to a previously public mutation returns UNAUTHORIZED.
- [ ] Manual test: valid session can call protected procedures.
- [ ] No regression on sign-in flow; logout clears server session.

**Tasks**

| # | Task | Notes |
|---|------|--------|
| T-01-1 | Add deps (`jose`, `bcryptjs`, `@types/bcryptjs`) | Match org approval process |
| T-01-2 | Implement `session.ts` (sign/verify, cookie names) | Align with Next.js App Router |
| T-01-3 | Wire `createTRPCContext` + `protectedProcedure` | `src/server/api/trpc.ts` |
| T-01-4 | Inventory all `publicProcedure` usages | `grep` / spreadsheet |
| T-01-5 | Migrate routers to `protectedProcedure` | Per-router PRs or one batch |
| T-01-6 | Remove client cookie forging path | Sign-in page, cookie helpers |
| T-01-7 | Add `whoami` if needed | UI atoms from server |
| T-01-8 | Update `.env.example` and README | Secrets documentation |

---

## US-02 — Server-side RBAC enforcement (P0)

**Summary:** Enforce permissions on the server using `ctx.user`; no security reliance on UI-only checks.

**Story:**  
As a **product owner**,  
I want **role and permission checks to execute on the server for each sensitive operation**,  
So that **bypassing the React UI cannot grant extra privileges**.

**Background:**  
RBAC runs only in `PermissionsProvider` / `has-permission` helpers; backend accepts any request; `hasPermissionToChangeUser` only in browser for role assignment.

**Acceptance criteria**

1. Reusable middleware factory: `requirePermission(permission: TPermission)` reads `ctx.user.roles`, runs same rules as `hasPermission()` server-side, throws `FORBIDDEN` on failure.
2. Spreadsheet or markdown table: **each protected procedure → required permission** (covers users, orders, devices, sensors, calendars, equipment, cars, customers, AWS, master-devices, contact-info, etc.).
3. Procedures that create/update/delete users validate **caller may assign target role** on the server (port logic from `UserManagementDialog` / `hasPermissionToChangeUser`).
4. Remove reliance on client-only hiding for authorization; UI may remain for UX.

**Tasks**

| # | Task |
|---|------|
| T-02-1 | Implement `requirePermission` middleware |
| T-02-2 | Map permissions to procedures (doc + code) |
| T-02-3 | Apply to `users` router (create/edit/delete) |
| T-02-4 | Apply to orders, devices, sensors, calendars, equipment, cars, customers, aws, master-devices, contact-info |
| T-02-5 | Add missing permissions in `permissions.ts` if needed (`manage:files`, `manage:equipment`, etc.) |

---

## US-03 — Stop password leakage & hash passwords at rest (P1)

**Summary:** Never return password fields to clients; store password hashes; migrate legacy plaintext safely.

**Story:**  
As a **user**,  
I want **my password never exposed in API responses or browser memory**,  
So that **credential theft risk is minimized**.

**Background:**  
`TRawUser` includes `Password`; `getAll` returns it; passwords may be plaintext in DB.

**Acceptance criteria**

1. API mapping (`mapUsers` / serializers) **strips `Password`** before any response.
2. Optionally adjust `GetAllEmployees` SP to omit password column.
3. Create/edit user flows hash password with **bcrypt** before SP call.
4. Login compares `bcrypt.compare` against stored hash.
5. One-time migration script/process for existing plaintext passwords (documented, tested on staging).
6. Verify network tab / DevTools: no password field in JSON payloads for user lists.

**Tasks**

| # | Task |
|---|------|
| T-03-1 | Strip password in `map-users` / routers |
| T-03-2 | Hash on create/update in tRPC |
| T-03-3 | Update `GetLoginUser` / login flow |
| T-03-4 | DB migration script for legacy rows |
| T-03-5 | Staging validation + rollback plan |

---

## US-04 — Server-derived audit identity (P0)

**Summary:** Remove `loggedInUserEmail` (and similar) from client-controlled mutation inputs; use `ctx.user` only.

**Story:**  
As a **compliance owner**,  
I want **audit fields in stored procedures to reflect the authenticated server user**,  
So that **audit trails cannot be spoofed**.

**Background:**  
Mutations pass `loggedInUserEmail` from client for SP audit parameters.

**Acceptance criteria**

1. Zod input schemas no longer include `loggedInUserEmail` for mutations (or server ignores client value).
2. All SP calls that need “acting user email” use `ctx.user.email` (or id) from verified session.
3. Regression tests or checklist for: user create/edit/delete, orders, sensors, devices, calendars, packing, etc.

**Tasks**

| # | Task |
|---|------|
| T-04-1 | Inventory inputs containing `loggedInUserEmail` |
| T-04-2 | Update Zod schemas + procedures |
| T-04-3 | Update frontend to stop sending spoofable fields |
| T-04-4 | Verify SP parameter binding end-to-end |

---

## US-05 — Rate limiting & sign-in abuse protection (P2)

**Summary:** Throttle `signIn`; restrict email enumeration via `getAllEmails`.

**Story:**  
As a **security engineer**,  
I want **rate limits on authentication and reduced email enumeration**,  
So that **brute-force and reconnaissance are harder**.

**Acceptance criteria**

1. `signIn`: max N attempts per email per time window (e.g. 5 / 15 min); returns 429 when exceeded.
2. Implementation works in deployment target (Edge middleware, Redis/Upstash, or approved in-memory for single instance — document limitation).
3. `getAllEmails`: either `protectedProcedure` post-auth only, removed, or replaced with non-enumerating UX (product decision documented).
4. Logging/monitoring for repeated failures (optional but recommended).

**Tasks**

| # | Task |
|---|------|
| T-05-1 | Choose rate-limit store (Vercel KV / Upstash / other) |
| T-05-2 | Implement limiter on `signIn` |
| T-05-3 | Product decision + implement `getAllEmails` change |
| T-05-4 | Metrics/alerts if available |

---

## US-06 — Eliminate SQL injection & unsafe raw SQL (P0)

**Summary:** Replace `$queryRawUnsafe` / string-built SQL with parameterized Prisma `$queryRaw` templates; remove unsafe `buildSqlParams` pattern.

**Story:**  
As a **platform engineer**,  
I want **no user-controlled values concatenated into SQL strings**,  
So that **the database cannot be compromised via injection**.

**Background:**  
Orders router and others interpolate `globalSearch`, `loggedInUserEmail`, `orderNumber`, filters into dynamic SQL; `buildSqlParams` still builds raw strings.

**Acceptance criteria**

1. **Orders router** (`getMany`, `getByOrderNumber`, `getManyGroupedByDateRange`, `assignCalibrators`, `getCalibrationHistory`, etc.): all dynamic SQL uses **tagged** `$queryRaw` / `$executeRaw` with parameters, not string `+=` with `${input.x}`.
2. `assignMbaReportNumbers` and any JSON through escaping reviewed; no quote-boundary escapes.
3. Repository-wide grep: `queryRawUnsafe|executeRawUnsafe` → zero or justified exceptions with security review.
4. `build-sql-params.ts` removed or refactored only after all callers safe.
5. Zod refinements: `orderNumber`, `globalSearch`, dates, comments per audit (length, regex).
6. **Users `delete`**: no raw `.join(',')` of ids into SQL without validated integer array server-side.

**Tasks**

| # | Task |
|---|------|
| T-06-1 | Rewrite `orders.ts` procedures with parameterized queries |
| T-06-2 | Audit `devices`, `sensors`, `calibrators`, `equipment`, `cars`, `customers`, `master-devices` |
| T-06-3 | Remove/replace `buildSqlParams` |
| T-06-4 | Add shared Zod schemas for SQL-adjacent inputs |
| T-06-5 | Pen-test or SQLmap-style sanity check on staging |

---

## US-07 — Secure AWS S3 file operations (P0)

**Summary:** Authenticate, authorize, validate, and scope all S3 upload/list/delete/move/presign flows.

**Story:**  
As a **data owner**,  
I want **file operations on S3 restricted to authorized users and safe paths**,  
So that **attackers cannot upload, delete, or exfiltrate arbitrary bucket content**.

**Background:**  
`uploadFile`, `deleteFile`, `deleteFolder`, `listFiles`, `getImageAsDataUrl`, `moveFile` described as public; path traversal; no size/type limits; long-lived presigned URLs.

**Acceptance criteria**

1. All AWS router procedures use `protectedProcedure` + `requirePermission` (e.g. `manage:files` / `view:files` — exact names in permissions model).
2. **File name / key validation:** reject `..`, leading `/`, null bytes; whitelist extensions (e.g. `.pdf`, `.png`, `.jpg`, `.jpeg`, `.xlsx`, `.docx`, `.csv`); normalize paths.
3. **Upload:** max decoded size (e.g. cap Base64 length); content type not blindly trusted where it matters.
4. **Scope:** keys prefixed by tenant/order/user as per product rules; list operations filtered to authorized prefixes.
5. **Presigned URLs:** reduced TTL (e.g. 5–15 minutes).
6. **moveFile:** destination validated same as upload paths.
7. **getImageAsDataUrl:** restrict to allowed types/paths or remove in favor of safer download flow.

**Tasks**

| # | Task |
|---|------|
| T-07-1 | Threat model + permission names |
| T-07-2 | Lock down `uploadFile` / `delete*` / `list*` / `moveFile` |
| T-07-3 | Implement validation helpers + tests |
| T-07-4 | Adjust presigned expiry |
| T-07-5 | Staging bucket policy review |

---

## US-08 — Ownership & data scoping across modules (P1)

**Summary:** Ensure queries return only authorized rows; mutations verify assignment/ownership.

**Story:**  
As a **calibration coordinator**,  
I want **each role to see and change only the data they are allowed to**,  
So that **cross-customer and cross-team data leaks are prevented**.

**Highlights from audit**

- **Dashboard:** customer names/numbers exposed without auth checks.
- **Orders:** status mutations open; customer directory enumerable.
- **Devices / calibration:** update/assign without ownership; URL order id change loads other orders; history filtered by spoofable email.
- **Sensors:** CRUD open.
- **Calendar:** delete/edit/create without ownership; client passes empty email to see all events.
- **Cars / equipment / master devices / customers / contact info / packing:** similar patterns.

**Acceptance criteria**

1. **Orders:** coordinators vs calibrators vs superAdmin data scope enforced server-side; SPs receive `ctx.user` filters.
2. **Calendar:** `edit`/`delete` verify creator or permission; `getAllEvents` uses server-side user id; remove client bypass of empty email.
3. **Devices / calibration:** mutations verify calibrator/validator assignment to `orderDetailsItemId`; wizard URL cannot load unauthorized orders (server check).
4. **Customers portal:** `getCustomerDashboardData` / `getUpcomingCalibrationInfo` use session user; customer sees only self; staff per policy.
5. **Contact info:** `getOneByOrderNumber` only after order access check.
6. **Equipment / cars:** CRUD gated by role permissions; `getEquipmentRelatedData` / `getCarRelatedData` do not leak full directory to anonymous callers.
7. Remove unsafe **client-side filtering** where server must filter (`UserManagementTable`, `CalibrationHistoryTable`, `BigCalendar` patterns).

**Tasks**

| # | Task |
|---|------|
| T-08-1 | Orders + dashboard scoping |
| T-08-2 | Devices + sensors + calibration wizard |
| T-08-3 | Calendar + cars |
| T-08-4 | Equipment + master devices |
| T-08-5 | Customers + contact-info + packing |
| T-08-6 | Remove client-only filtering where redundant |

---

## US-09 — Global input validation hardening (P1)

**Summary:** Shared Zod schemas for emails, dates, comments, order numbers, arrays; cap bulk operations.

**Story:**  
As an **engineer**,  
I want **consistent validation for all external inputs**,  
So that **unexpected SP errors, truncation, and injection are reduced**.

**Acceptance criteria**

1. New `src/lib/schemas/common.ts` (or equivalent): `emailSchema`, `orderNumberSchema`, `dateStringSchema`, `commentSchema`, `globalSearchSchema`, `idArraySchema` with max lengths and formats.
2. Replace bare `z.string()` on sensitive fields across routers.
3. **orderBy** in list endpoints: `z.enum([...])` of allowed columns only — **no** fallback to raw user string in SQL (equipment `getAll` issue).
4. Bulk deletes: `z.array(z.number()).max(100)` (or agreed cap).

**Tasks**

| # | Task |
|---|------|
| T-09-1 | Create shared schemas |
| T-09-2 | Apply to users, orders, equipment, cars |
| T-09-3 | Fix `orderBy` allowlists |
| T-09-4 | Lint or test for bare strings on critical fields |

---

## US-10 — Password complexity policy (P2)

**Summary:** Enforce min length, character classes in Zod + UI for user password fields.

**Acceptance criteria**

1. `user-dialog-schema`: min length (e.g. 8), max (e.g. 128), uppercase, lowercase, digit (per policy).
2. Inline validation messages in `UserManagementDialog`.
3. Server-side duplicate validation in tRPC procedure.

**Tasks**

| # | Task |
|---|------|
| T-10-1 | Update Zod schema |
| T-10-2 | Mirror validation in procedure |
| T-10-3 | UX copy for errors |

---

## US-11 — Unified access-control pattern (P2)

**Summary:** Backend uses only `requirePermission`; reduce ad-hoc `isSuperAdmin` in server code.

**Acceptance criteria**

1. Guidelines doc: server must not use raw role helpers for authorization except where mapped to permissions.
2. Refactor hotspots called out in audit (inconsistent strategy).
3. Permission reference table complete for backend.

**Tasks**

| # | Task |
|---|------|
| T-11-1 | Document pattern |
| T-11-2 | Refactor server role checks |
| T-11-3 | Peer review |

---

## US-12 — Error handling & information leakage (P2)

**Summary:** Sanitize client errors; structured server logging; fix silent partial failures.

**Acceptance criteria**

1. tRPC `errorFormatter`: log full detail server-side; client receives safe message (no raw SQL/stack).
2. Dashboard procedures: try/catch DB errors; user-friendly fallback state.
3. `getUserRelatedData`: handle `Promise.allSettled` failures — structured response or error, not silent `undefined`.
4. `getChannelsList` (sensors): distinguish failure vs empty (return error flag or throw).

**Tasks**

| # | Task |
|---|------|
| T-12-1 | Implement `errorFormatter` |
| T-12-2 | Fix dashboard + users partial failure |
| T-12-3 | Fix sensors channel list |
| T-12-4 | Add React error boundaries on critical pages (optional) |

---

## US-13 — Server-side audit logging for mutations (P2)

**Summary:** Immutable audit trail for who did what, when, on mutations.

**Acceptance criteria**

1. Middleware after mutations: `ctx.user`, procedure name, sanitized input, timestamp, success/failure.
2. Storage: `AuditLog` table or approved external sink.
3. Attached to `protectedProcedure` chain so coverage is broad.

**Tasks**

| # | Task |
|---|------|
| T-13-1 | Schema + migration |
| T-13-2 | Middleware implementation |
| T-13-3 | Retention & PII policy |

---

## US-14 — Dashboard business data & UI robustness (P3)

**Summary:** Replace hardcoded agent names; department card color fallback; stable list keys; caching/freshness.

**Acceptance criteria**

1. Agent filter: DB-driven or config — remove four-name Hebrew hardcode.
2. `DepartmentCard`: default Tailwind when color unknown.
3. `DepartmentCards`: `key={department.id}` (or stable id), not index.
4. tRPC `staleTime` for dashboard and reference queries; optional “last updated” label.

**Tasks**

| # | Task |
|---|------|
| T-14-1 | DB/config for agents |
| T-14-2 | Color fallback + keys |
| T-14-3 | React Query / tRPC cache tuning + UI timestamp |

---

## US-15 — Validator & notification safety (P3)

**Summary:** Server-side validator checks; validate `redirectPage` for notifications.

**Acceptance criteria**

1. `assignValidatedStatus`: verify caller is assigned validator for resource.
2. `calibrator-notifications` `create`: not spoofable; `redirectPage` relative path only (`startsWith('/')`, no `//`, no `..`) or enum.

**Tasks**

| # | Task |
|---|------|
| T-15-1 | Validator assignment check |
| T-15-2 | Notification input hardening |

---

## US-16 — Driver module: localStorage & packing context (P3)

**Summary:** Minimize sensitive data in `localStorage`; clear on logout; acknowledge packing uses orders router.

**Acceptance criteria**

1. Store only minimal ids in `localStorage`, not full PII objects.
2. Logout clears app-specific keys.
3. Document dependency on secured orders API (US-06/US-08).

**Tasks**

| # | Task |
|---|------|
| T-16-1 | Refactor `ClientList` storage |
| T-16-2 | Clear keys in logout flow |

---

## US-17 — Incomplete features: customer portal & electronics (P3)

**Summary:** Wire forms to backend or remove navigation to mock pages.

**Acceptance criteria**

1. `customer-profile`, `customer-devices/add`, `customer-invoice`: real mutations or feature flags / hidden routes.
2. `ElectronicsTable`: integrate with equipment/backend or remove page.

**Tasks**

| # | Task |
|---|------|
| T-17-1 | Product decision per page |
| T-17-2 | Implement or remove |

---

## US-18 — Master devices: JSON validation for SP payloads (P3)

**Summary:** Strict Zod schemas for `savePointsConfiguration` / `assignMeasurementDeviceToOrderDetailsItems` JSON.

**Acceptance criteria**

1. Validate nested structures before `$executeRaw` / SP.
2. Reject oversize strings, invalid channel numbers, etc.

**Tasks**

| # | Task |
|---|------|
| T-18-1 | Define Zod schemas for JSON payloads |
| T-18-2 | Unit tests for edge cases |

---

# Priority rollup (suggested Jira Priority field)

| Priority | Stories |
|----------|---------|
| **Highest / P0** | US-01, US-02, US-04, US-06, US-07 |
| **High / P1** | US-03, US-08, US-09 |
| **Medium / P2** | US-05, US-10, US-11, US-12, US-13 |
| **Low / P3** | US-14–US-18 |

---

# Optional: Jira CSV header (manual import)

```text
Summary,Issue Type,Epic Link,Priority,Description,Acceptance Criteria
```

Paste Epic name into **Epic Link** column after Epic exists, or use Jira’s parent field for next-gen projects.

---

*Generated for MABA audit remediation; align task IDs with your Jira project key (e.g. `MABA-123`).*
