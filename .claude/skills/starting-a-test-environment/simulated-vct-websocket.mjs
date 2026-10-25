/*
 * Stand-in for the VCT comm server's WebSocket endpoint, so the app's socket can reach the
 * "connected" state on a machine with no VCT and no logger attached.
 *
 * The real thing is Systems/VCT, whose WebSocketListenPrefix defaults to
 * http://localhost:5001/ws/ (VCTSettings.DEFAULT_WEBSOCKET_LISTEN_PREFIX). This listens on the
 * same host and path so NEXT_PUBLIC_WEBSOCKET_URL needs no change.
 *
 * It borrows the `ws` package from an app checkout rather than carrying its own dependency, so
 * there is nothing to install:
 *
 *   node simulated-vct-websocket.mjs <path-to-app-checkout> [port] [path]
 *   node simulated-vct-websocket.mjs C:\Users\skulas\dev\pr141
 *
 * What it does NOT do: emit logger data frames. Calibration graphs stay empty unless
 * NEXT_PUBLIC_CALIBRATION_USE_MOCK is "true" or a real logger is attached. It is enough to prove
 * the socket connects, disconnects and round-trips a message - not to exercise a calibration run.
 */
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

const [appRepo, portArg, pathArg] = process.argv.slice(2);

if (!appRepo) {
  console.error('usage: node simulated-vct-websocket.mjs <path-to-app-checkout> [port] [path]');
  process.exit(1);
}
if (!fs.existsSync(path.join(appRepo, 'node_modules', 'ws'))) {
  console.error(`no 'ws' package under ${appRepo}\\node_modules - install the app checkout first`);
  process.exit(1);
}

const port = Number(portArg ?? 5001);
const wsPath = pathArg ?? '/ws';

const require = createRequire(pathToFileURL(path.join(appRepo, 'package.json')));
const { WebSocketServer } = require('ws');

const server = new WebSocketServer({ port, path: wsPath });

server.on('connection', (socket) => {
  console.log('client connected');
  socket.send('Hello from the simulated VCT server');

  socket.on('message', (data) => {
    const text = data.toString();
    console.log('<-', text);
    // The app awaits a reply for this one; without it sendValidateMABA never resolves.
    if (text.includes('ValidateMABA')) {
      socket.send('Valid');
    }
  });

  socket.on('close', () => console.log('client disconnected'));
});

console.log(`simulated VCT websocket listening on ws://localhost:${port}${wsPath}`);
