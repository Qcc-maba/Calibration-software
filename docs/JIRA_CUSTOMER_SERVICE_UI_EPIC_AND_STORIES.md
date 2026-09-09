# Jira Backlog — Customer Service UI (Figma)

**Purpose:** Create or extend the **Customer Service** Epic in Jira; attach these Stories for UI implementation work.  
**Language:** English (Epic, Stories, AC).  
**Source:** Figma workspace — Customer Service management screens (RTL Hebrew concepts, dashboards, split layouts, tables, drawers).

---

## Figma file (MBA — Main)

| | |
|:---|:---|
| **Design file** | [MBA — Main](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main) |
| **File key** | `VBvERz5CDs6MBg1kiiGV1S` |
| **Board you shared** | [Frame 1340 — full dashboard (split + table)](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4039) · node `9251:4039` |

**Note:** The links below were resolved from this file’s layer tree. Older frame labels in the backlog (e.g. 37068, 37069, 37070 as separate artboards) may refer to other pages or renames—use *Copy link* on the exact frame in Figma if a screen moved.

---

## How to use in Jira

1. Open your existing **Customer Service** Epic (or create one using [Epic](#epic-customer-service--ui-implementation-from-figma) below).
2. For each **User Story**, create a Story issue and set **parent** / **Epic Link** to that Epic.
3. UI developers implement against **Acceptance criteria**; design QA uses the same list for review.
4. Paste **Figma frame links** (see [How to copy a Figma link](#how-to-copy-a-figma-link-to-a-frame)) into each Story in Jira, or attach exported PNGs.

---

## How to copy a Figma link to a frame

1. Open your file in [Figma](https://www.figma.com/).
2. Select the **frame** (artboard) for the relevant screen.
3. Right-click the frame → **Copy/Paste** → **Copy link** (or use the Share control and copy the URL).
4. The URL looks like: `https://www.figma.com/design/<FILE_KEY>/<file-name>?node-id=<NODE_ID>&...`  
   Paste that URL into the Story’s **Figma link** field in this doc or in Jira.

**Optional exports:** For each story you can also **Export** the frame as PNG (right-click frame → Export) and save under `docs/assets/customer-support/` using the filenames suggested in each US (e.g. `us-cs-02-dashboard.png`).

---

## Epic: Customer Service — UI implementation (from Figma)

| Field | Content |
|-------|---------|
| **Epic Name / Summary** | CUSTOMER SUPPORT *(Jira: [MABA-771](https://calibration-maba.atlassian.net/browse/MABA-771))* |
| **Epic Type** | Epic |
| **Description** | Deliver the Customer Service area of the product to match approved Figma screens: RTL-first layout, operational dashboards with KPIs and charts, split-pane ticket/task workspaces, full-width record tables, and secondary flows in drawers/modals. Work is **UI/UX implementation** (components, layout, states, visual status language)—wire to real APIs in separate stories if needed. |
| **Business outcome** | Agents and supervisors can monitor service workload, triage tickets, and act on records in a consistent, readable Hebrew (RTL) interface aligned with design. |
| **Success criteria (Epic)** | (1) All listed frames are represented as routes or clear UI states. (2) RTL and status colors behave consistently. (3) Reusable primitives (table, KPI card, charts shell, drawer) exist and match Figma hierarchy. |

**Figma (Epic-level)**

| | |
|:---|:---|
| **File** | [MBA — Main](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main) |
| **Primary board (your link)** | [Frame 1340](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4039) (`9251:4039`) |
| **Overview screenshot** | [Figure 1](#figure-1--customer-support-figma-board-overview) — optional PNG export to `docs/assets/customer-support/customer-support-figma-board.png` |

**Suggested labels:** `customer-service`, `ui`, `figma`, `rtl`, `frontend`  
**Suggested components:** `web`, `design-system` (adjust to your project)

**Created in Jira (MABA):**

| Work item | Key |
|-----------|-----|
| Epic **CUSTOMER SUPPORT** | [MABA-771](https://calibration-maba.atlassian.net/browse/MABA-771) |
| US-CS-01 | [MABA-772](https://calibration-maba.atlassian.net/browse/MABA-772) |
| US-CS-02 | [MABA-773](https://calibration-maba.atlassian.net/browse/MABA-773) |
| US-CS-03 | [MABA-774](https://calibration-maba.atlassian.net/browse/MABA-774) |
| US-CS-04 | [MABA-775](https://calibration-maba.atlassian.net/browse/MABA-775) |
| US-CS-05 | [MABA-776](https://calibration-maba.atlassian.net/browse/MABA-776) |
| US-CS-06 | [MABA-777](https://calibration-maba.atlassian.net/browse/MABA-777) |
| US-CS-07 | [MABA-778](https://calibration-maba.atlassian.net/browse/MABA-778) |

---

# User Stories (with Acceptance Criteria)

---

## US-CS-01 — RTL application shell & Customer Service navigation (P0)

**Summary:** Implement the CS module inside an RTL-capable shell with top navigation matching Figma.

**Figma design reference**

| | |
|:---|:---|
| **Layer** | **Header** — tab row (“כיולים קרובים”, “הזמנות לאישור”, “הצעות מחיר לאישור”) inside the main card. |
| **Figma link** | [Header — `9251:4264`](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4264) · [Right pane “Vertical” (full chrome)](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4262) (`9251:4262`) |
| **Screenshot (repo)** | Optional: `docs/assets/customer-support/us-cs-01-shell-nav.png` — crop from export of [Frame 1340](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4039). |

**Story:**  
As a **Customer Service user**,  
I want **the CS area to render right-to-left with a clear top bar and menu**,  
So that **labels, alignment, and navigation match Hebrew usage and the design**.

**Acceptance criteria**

1. Root layout for CS routes uses **logical CSS** (margin-inline, padding-inline, `start`/`end`) or equivalent so RTL does not break when toggling direction.
2. **Top navigation** includes logo/branding and primary menu items as in Figma; order and alignment suit RTL (e.g. menu from the right).
3. Content region below the nav is full-width with consistent horizontal padding per Figma specs.
4. No hard-coded `left`/`right` for layout that should flip in RTL unless documented as an exception.
5. Document or implement a **single source** for `dir="rtl"` (e.g. layout segment or html `lang` + `dir` for CS).

**Definition of Done**

- [ ] Visual review against Figma dashboard frame(s) for shell + nav only.
- [ ] Spot-check one LTR comparison if the app supports both (optional).

---

## US-CS-02 — Customer Service operations dashboard (P0)

**Summary:** Build the high-level dashboard: KPI cards, trend line chart, and supporting lists/sections.

**Figma design reference**

| | |
|:---|:---|
| **Layers** | Left column **Frame 37072** — category grid **Frame 37071**, sales target **Frame 37080**, yearly sales chart **Frame 37081**. |
| **Figma links** | [Frame 37072 — left stack](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4194) (`9251:4194`) · [Frame 37071 — KPI / category tiles](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4195) · [Frame 37081 — line chart block](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9258-926) (`9258:926`) |
| **Screenshot (repo)** | `docs/assets/customer-support/us-cs-02-dashboard.png` — export [9251:4194](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4194) or full [Frame 1340](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4039). |

**Story:**  
As a **supervisor**,  
I want **a dashboard with KPI cards, a main trend chart, and compact activity or summary blocks**,  
So that **I can see workload and trends at a glance**.

**Acceptance criteria**

1. **KPI grid:** Color-coded cards (e.g. yellow / green / pink-red per design) show counts or metrics; responsive wrap matches Figma breakpoints.
2. **Line chart:** Occupies designated area; uses design tokens for axes, grid, and series color; supports empty and loading states (placeholders acceptable until data is wired).
3. **Secondary blocks:** Smaller tables or lists (e.g. recent items, priorities) match spacing, typography, and card containers from Figma.
4. All text and numbers respect **RTL** (chart legends and tooltips where applicable).
5. **Skeleton/loading** and **empty** states are defined so developers do not ship a blank screen.

**Definition of Done**

- [ ] Pixel-approximate match to Figma dashboard frames; any deviation documented.

---

## US-CS-03 — Split-pane ticket & task workspace (P0)

**Summary:** Implement master–detail layouts: sidebar (categories, agents, or status) plus main data table, with a chart in the sidebar area per frame variants.

**Figma design reference**

| | |
|:---|:---|
| **Layer** | **Frame 1340** — left column (widgets + chart) + right **Vertical** (table). |
| **Figma link** | [Frame 1340 — full split layout](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4039) (`9251:4039`) |
| **Note** | This board shows **line** chart + category grid; a **donut** variant may live on another page—add a second link if design moved. |
| **Screenshot (repo)** | `docs/assets/customer-support/us-cs-03-split.png` — export [9251:4039](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4039). |

**Story:**  
As an **agent**,  
I want **a sidebar for filtering or context and a large table for tickets/tasks**,  
So that **I can focus on a subset and work the queue without losing context**.

**Acceptance criteria**

1. **Layout:** Two-pane structure: narrow sidebar + flexible main area; proportions align with Figma (37070, 37072, 37083-style frames).
2. **Sidebar content:** Supports list or grouped items (e.g. status categories); **selection** updates the main table or highlighted context (master–detail behavior).
3. **Charts in sidebar:** At least one variant includes a **donut** (status breakdown) and another a **line** trend—use shared chart components; same loading/empty behavior as US-CS-02.
4. **Main table:** Full feature set per design—columns, header row, row hover/focus, status badges in cells.
5. **Scrolling:** Sidebar and main area scroll independently where Figma implies overflow.
6. Keyboard: basic **focus order** is logical in RTL (no trapped focus in sidebar).

**Definition of Done**

- [ ] Both sidebar chart variants (donut + line) demonstrable via route or story toggles.

---

## US-CS-04 — Full-width browse table view (P1)

**Summary:** Dense, full-width table for browsing many records with standard table UX.

**Figma design reference**

| | |
|:---|:---|
| **Layer** | **Table** — dense data grid inside the right card (under Header). |
| **Figma link** | [Table — `9251:4270`](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4270) · [Vertical — full right column context](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4262) |
| **Screenshot (repo)** | `docs/assets/customer-support/us-cs-04-full-table.png` — export [9251:4270](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4270). |

**Story:**  
As an **agent**,  
I want **a wide table with many columns for scanning and sorting records**,  
So that **I can find tickets quickly in bulk views**.

**Acceptance criteria**

1. Table uses **full width** of content area; horizontal scroll on small viewports if columns do not fit.
2. Column headers support **sort** affordance where design shows it (even if API sorts later).
3. **Status badges** and inline indicators match the shared visual language (US-CS-06).
4. **Floating action** (e.g. blue circular control / primary CTA in Figma) is positioned per design and has an accessible label.
5. **Toolbar/filter row** (if present in Figma) aligns RTL and leaves room for future filter wiring.

**Definition of Done**

- [ ] Table component reused or extended from US-CS-03 where possible (single table primitive).

---

## US-CS-05 — Side drawer & modal flows for ticket actions (P1)

**Summary:** Narrow vertical panel for create/edit flows without leaving the main page.

**Figma design reference**

| | |
|:---|:---|
| **Layer** | **Vertical** — tall right-hand column (tabs + table workspace). For a separate slide-over drawer, use *Copy link* on that component if it exists on another frame. |
| **Figma link** | [Vertical — `9251:4262`](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4262) · [card — `9251:4263`](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4263) |
| **Screenshot (repo)** | `docs/assets/customer-support/us-cs-05-vertical-pane.png` — export [9251:4262](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4262). |

**Story:**  
As an **agent**,  
I want **a drawer or modal with a form to create or edit a ticket**,  
So that **I can complete actions quickly without a full page reload**.

**Acceptance criteria**

1. **Drawer/modal** opens from the correct trigger (e.g. FAB or row action); closes via overlay click, Esc, and explicit close control per accessibility guidelines.
2. Form fields match Figma order, labels, and primary **Submit** placement (RTL: primary action on leading side per design system).
3. **Validation states** (error text, field borders) have defined styles even if rules are stubbed.
4. Focus moves into the drawer on open and returns to trigger on close.
5. Mobile: behavior degrades to full-screen sheet or modal if specified in design notes; otherwise document desktop-first.

**Definition of Done**

- [ ] Storybook or demo route shows open/close and validation styling.

---

## US-CS-06 — Shared Customer Service UI kit & status language (P0)

**Summary:** Extract reusable primitives and document the status color system for CS screens.

**Figma design reference**

| | |
|:---|:---|
| **Layer** | **Frame 37071** — colored category / SLA tiles (top-left grid). |
| **Figma link** | [Frame 37071 — `9251:4195`](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4195) |
| **Screenshot (repo)** | `docs/assets/customer-support/us-cs-06-components.png` — export [9251:4195](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4195). |

**Story:**  
As a **UI developer**,  
I want **shared components and tokens for KPIs, badges, charts, and tables**,  
So that **all CS screens stay consistent and cheap to extend**.

**Acceptance criteria**

1. **Status colors:** Document mapping for **green** (e.g. completed/healthy), **yellow** (pending/in progress), **pink/red** (urgent/overdue)—implemented as design tokens or theme variables, not one-off hex in each file.
2. **Badge** component: variants map to semantic statuses; works on light backgrounds inside tables and cards.
3. **KPI card** component: supports icon, title, value, optional trend; uses shared elevation/radius.
4. **Chart container:** Shared title area, padding, and empty state for line and donut charts.
5. **Data table primitives:** Header cell, body cell, row selection style (if any), align numbers per RTL rules.
6. Small **profile / avatar** blocks from component frames match typography and spacing when used in dashboard side areas.

**Definition of Done**

- [ ] Short README or Storybook docs list exports and when to use each variant.

---

## Optional — US-CS-07 — Accessibility & performance baseline (P2)

**Summary:** Baseline a11y and perf for CS routes.

**Figma design reference**

| | |
|:---|:---|
| **Scope** | All nodes under [Frame 1340](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4039) or the whole [file](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main). |
| **Figma link** | [Frame 1340](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4039) |

**Acceptance criteria**

1. Charts expose accessible names or summaries where WCAG requires; tables use `<table>` semantics or equivalent roles.
2. Color is not the only indicator for status (icon or text duplicate).
3. Large lists/tables: document virtualization or pagination follow-up if row counts exceed N.

---

## Figure 1 — Customer Support Figma board (overview)

**Open in Figma:** [Frame 1340 — full board](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4039) (`9251:4039`).

Optional local PNG (for offline README / PRs):

![Customer Support — full Figma board (optional export)](assets/customer-support/customer-support-figma-board.png)

1. Open the link above → **Export** the frame as PNG (or use Figma’s export panel).
2. Save as `docs/assets/customer-support/customer-support-figma-board.png`.

Until that file exists, use the **Figma link** as the source of truth for visuals.

---

## Traceability

| Story ID | Figma node (resolved) | Direct link |
|----------|------------------------|-------------|
| US-CS-01 | Header `9251:4264`, Vertical `9251:4262` | [Header](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4264) · [Vertical](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4262) |
| US-CS-02 | `9251:4194`, `9251:4195`, `9258:926` | [37072](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4194) · [37071](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4195) · [37081 chart](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9258-926) |
| US-CS-03 | `9251:4039` | [Frame 1340](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4039) |
| US-CS-04 | `9251:4270` | [Table](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4270) |
| US-CS-05 | `9251:4262`, `9251:4263` | [Vertical](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4262) · [card](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4263) |
| US-CS-06 | `9251:4195` | [Frame 37071](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4195) |
| US-CS-07 | Full board / file | [Frame 1340](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main?node-id=9251-4039) · [file](https://www.figma.com/design/VBvERz5CDs6MBg1kiiGV1S/MBA---Main) |
