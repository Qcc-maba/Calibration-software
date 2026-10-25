# The app repo's lint rules that reject new files

`lint-staged` runs eslint on staged files and **reverts the whole commit** when it fails, then
`tsc --noEmit` runs. Run `npx eslint <files>` before committing. All of these were hit in one sitting.

## `playwright/no-standalone-expect` fires on vitest tests

The plugin's recommended config is applied **repo-wide**, not scoped to `e2e/`, and it recognises
`test()` as a test block but **not `it()`**. So a unit test written as

```ts
describe('x', () => {
  it('does the thing', () => {
    expect(value).toBe(1);      // ← "Expect must be inside of a test block"
  });
});
```

fails, once per `expect`. Existing `it()`-based unit tests in `src/` pass only because they assert
with `node:assert/strict` and never call `expect`.

**Fix in a feature commit:** use `test()` instead of `it()`. One line, tests unchanged.

**The real fix, which needs its own commit:** scope `playwright.configs['flat/recommended']` to
`files: ['e2e/**/*.{ts,tsx}']` in `eslint.config.js`. Do not fold that into a feature commit — it
changes linting for the whole repository.

## The rest

| Rule | What it wants |
|---|---|
| `jsdoc/require-param`, `require-returns` | a **description**, not just the tag. `eslint --fix` inserts the bare tag and then fails on the missing text |
| `unicorn/prefer-node-protocol` | `node:fs`, `node:path` |
| `unicorn/prefer-number-properties` | `Number.parseInt`, not `parseInt` |
| `unicorn/prefer-string-raw` | `String.raw` instead of escaping backslashes |
| `unicorn/prefer-set-has` | a `Set` for a membership test |
| `unicorn/import-style` | default import for `node:path` — `import path from 'node:path'` |
| `unicorn/consistent-function-scoping` | a helper arrow function defined inside a component moves to module scope |
| `react/jsx-filename-extension` | a component that returns `null` has no JSX, so the file must be `.ts` |
| `check-file/filename-naming-convention` | kebab-case — renaming `BackgroundDataProcessor.tsx` ends at `background-data-processor.ts` |

`scripts/*.mjs` sits outside `tsconfig`, so the type-aware rules cannot parse it; it is ignored in
`eslint.config.js` on purpose.

## `tsc` fails on a file you did not write

A stale `.next/types/validator.ts` references routes that have since moved or been deleted. Delete
that file — not the route.
