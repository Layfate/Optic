import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { root } from './modules.mjs';

const escape = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const cpuSource = `local RunService = game:GetService("RunService")
local connection
local elapsed = 0
connection = RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    local value = 0
    for i = 1, 30000 do value += math.sqrt(i) end
    script:SetAttribute("Work", value)
    if elapsed > 60 then connection:Disconnect() end
end)
`;
const riskSource = `-- Disabled scan fixture: this script never executes.
for i = 1, 3 do
    workspace.ChildAdded:Connect(function() end)
end
`;
const item = (name, source, disabled = false, cls = 'Script') => `<Item class="${cls}"><Properties><string name="Name">${name}</string><bool name="Disabled">${disabled}</bool><ProtectedString name="Source">${escape(source)}</ProtectedString></Properties></Item>`;
const xml = `<?xml version="1.0" encoding="utf-8"?>
<roblox version="4">
<Item class="Workspace"><Properties><string name="Name">Workspace</string></Properties>
<Item class="Part"><Properties><string name="Name">Baseplate</string><bool name="Anchored">true</bool><Vector3 name="size"><X>256</X><Y>1</Y><Z>256</Z></Vector3></Properties></Item>
</Item>
<Item class="ServerScriptService"><Properties><string name="Name">ServerScriptService</string></Properties>${item('OpticCpuFixture', cpuSource)}${item('OpticConnectionFixture', riskSource, true)}</Item>
<Item class="StarterPlayer"><Properties><string name="Name">StarterPlayer</string></Properties><Item class="StarterPlayerScripts"><Properties><string name="Name">StarterPlayerScripts</string></Properties>${item('OpticClientFixture', cpuSource, false, 'LocalScript')}</Item></Item>
</roblox>
`;
await mkdir(path.join(root, 'test-results'), { recursive: true });
await writeFile(path.join(root, 'test-results/Optic-Studio-Test.rbxlx'), xml);
console.log('Created isolated local Optic test place.');
