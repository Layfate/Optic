import { LuauState } from 'luau-web';
import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { root, readModules, loader } from './modules.mjs';

const state = await LuauState.createAsync({ print: (...args) => console.log(...args) });
try {
  const modules = await readModules();
  for (const [name, source] of Object.entries(modules)) state.loadstring(source, name, true);
  const files = (await readdir(path.join(root, 'tests'))).filter(f => f.endsWith('.spec.luau')).sort();
  let total = 0;
  for (const file of files) {
    const source = await readFile(path.join(root, 'tests', file), 'utf8');
    const code = loader(modules) + `\nlocal require = __require\nlocal script = {Parent = __root}\n` + source;
    const result = await state.loadstring(code, file, true)();
    total += Number(result[0] ?? 0);
  }
  const bundle = await readFile(path.join(root, 'dist/Optic.plugin.luau'), 'utf8').catch(() => null);
  if (bundle) state.loadstring(bundle, 'Optic.plugin.luau', true);
  console.log(`Luau: ${total} behavioral tests passed; ${Object.keys(modules).length} modules compiled${bundle ? '; bundle compiled' : ''}.`);
} finally { state.destroy(); }
