import { readdir, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export const root = fileURLToPath(new URL('../', import.meta.url));
export async function readModules() {
  const entries = await readdir(path.join(root, 'src')).catch(() => []);
  const result = {};
  for (const file of entries.filter(f => f.endsWith('.luau') && f !== 'init.server.luau').sort()) {
    result[file.slice(0, -5)] = await readFile(path.join(root, 'src', file), 'utf8');
  }
  return result;
}

// The bundle uses the same sibling ModuleScript relationship as the XML model.
export function loader(modules) {
  const names = Object.keys(modules).sort();
  return `local __root = {}\nlocal __factories = {}\nlocal __cache = {}\nlocal __loading = {}\n`
    + names.map(name => `__root[${JSON.stringify(name)}] = {Name = ${JSON.stringify(name)}, Parent = __root}\n`).join('')
    + `local function __require(node)\n assert(node and __factories[node.Name], "Missing Optic module")\n local name = node.Name\n if __cache[name] ~= nil then return __cache[name] end\n assert(not __loading[name], "Cyclic Optic dependency: " .. name)\n __loading[name] = true\n local value = __factories[name](node, __require)\n __cache[name] = value\n __loading[name] = nil\n return value\nend\n`
    + names.map(name => `__factories[${JSON.stringify(name)}] = function(script, require)\n${modules[name]}\nend\n`).join('');
}
