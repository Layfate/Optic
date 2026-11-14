import test from 'node:test';
import assert from 'node:assert/strict';
import { LuauState } from 'luau-web';
import { readModules, loader } from '../scripts/modules.mjs';

test('scanning the advertised 256 KiB limit does not block for multiple seconds', async () => {
  const state = await LuauState.createAsync();
  try {
    const fn = state.loadstring(loader(await readModules())
      + '\nreturn __require(__root.Scanner).scan(string.rep(" ", 256 * 1024), "Large")', 'large', true);
    const start = performance.now();
    await fn();
    // Old implementation was reproducibly >6s; leave generous headroom for CI.
    assert.ok(performance.now() - start < 2500, 'A maximum-size blank source must not monopolize Studio for seconds.');
  } finally { state.destroy(); }
});
