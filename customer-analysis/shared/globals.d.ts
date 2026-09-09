// Injected at build time by script/build.ts (esbuild define for the server,
// vite define for the client), so both halves carry the same stamp.
//
// It is NOT defined when running from source (tsx / vite dev) unless the vite
// config supplies a fallback, so always read it through a typeof guard.
declare const __BUILD_ID__: string;
