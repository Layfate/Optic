import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { LuauState } from 'luau-web';
import path from 'node:path';
import { root, readModules, loader } from '../scripts/modules.mjs';

test('XML model preserves exact source in a Script root and ModuleScript children', async () => {
  execFileSync(process.execPath, ['scripts/build.mjs'], { cwd: root });
  const xml = await readFile(path.join(root, 'dist/Optic.rbxmx'), 'utf8');
  const entry = await readFile(path.join(root, 'src/init.server.luau'), 'utf8');
  const items = [...xml.matchAll(/<Item class="(Script|ModuleScript)" referent="([^"]+)"><Properties><string name="Name">([^<]+)<\/string><ProtectedString name="Source">([\s\S]*?)<\/ProtectedString><\/Properties>/g)];
  const decode = s => s.replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'").replaceAll('&amp;', '&');
  assert.equal(items[0][1], 'Script');
  assert.equal(items[0][3], 'Optic');
  assert.equal(decode(items[0][4]), entry);
  const modules = await readModules();
  assert.equal(items.length, Object.keys(modules).length + 1);
  for (const item of items.slice(1)) {
    assert.equal(item[1], 'ModuleScript');
    assert.equal(decode(item[4]), modules[item[3]]);
  }
});

test('repeat builds produce byte-identical installable artifacts', async () => {
  const build = () => execFileSync(process.execPath, ['scripts/build.mjs'], { cwd: root });
  build();
  const first = await Promise.all(['Optic.rbxmx', 'Optic.plugin.luau'].map(f => readFile(path.join(root, 'dist', f))));
  build();
  const second = await Promise.all(['Optic.rbxmx', 'Optic.plugin.luau'].map(f => readFile(path.join(root, 'dist', f))));
  first.forEach((buffer, i) => assert.deepEqual(buffer, second[i]));
});

test('standalone loader resolves sibling dependencies and caches module identity', async () => {
  const state = await LuauState.createAsync();
  try {
    const result = await state.loadstring(loader({ A: 'return {value = 7}', B: 'return require(script.Parent.A)' })
      + '\nlocal a = __require(__root.A)\nassert(a == __require(__root.B))\nreturn a.value', 'loader', true)();
    assert.equal(result[0], 7);
  } finally { state.destroy(); }
});

test('distributed standalone plugin compiles as Luau', async () => {
  const state = await LuauState.createAsync();
  try { state.loadstring(await readFile(path.join(root, 'dist/Optic.plugin.luau'), 'utf8'), 'Optic', true); }
  finally { state.destroy(); }
});
