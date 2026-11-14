// Installs a temporary acceptance bridge into a copy of the built plugin.
// No test bridge is written into src/ or dist/.
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { root } from './modules.mjs';
const xml = await readFile(path.join(root, 'dist/Optic.rbxmx'), 'utf8');
const source = await readFile(path.join(root, 'src/App.luau'), 'utf8');
const bridge = `
    -- Temporary local acceptance harness, only in the installed test copy.
    if game.PlaceId == 0 then
        local bridge = Instance.new("BindableFunction")
        bridge.Name = "OpticAcceptanceBridge"
        bridge.OnInvoke = function(command, argument)
            if command == "state" then return studio.http:JSONEncode(Report.snapshot(state()))
            elseif command == "tab" then ui:switch(argument); return true
            elseif command == "enabled" then widget.Enabled = argument; return true
            elseif command == "open" then studio:open(studio.findings[1]); return true
            elseif command == "report" then return studio.http:JSONEncode(ui.reportChunks)
            elseif command == "action" then
                local allowed = {scope=true, scan=true, baseline=true, report=true, format=true, target=true, capture=true}
                assert(allowed[argument], "Unsupported acceptance action")
                ui.actions[argument](); return true
            end
            error("Unknown acceptance command")
        end
        bridge.Parent = widget
        table.insert(connections, bridge.Destroying:Connect(function() end))
    end
`;
const instrumented = source.replace('    visibility()\nend\nreturn App', bridge + '    visibility()\nend\nreturn App');
if (instrumented === source) throw new Error('App acceptance injection point was not found.');
const escape = s => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
const original = `<Item class="ModuleScript" referent="OpticApp"><Properties><string name="Name">App</string><ProtectedString name="Source">${escape(source)}</ProtectedString></Properties>`;
if (!xml.includes(original)) throw new Error('App XML was not found.');
const output = xml.replace(original, original.replace(escape(source), escape(instrumented)));
const installed = path.join(process.env.LOCALAPPDATA, 'Roblox/Plugins/Optic.rbxmx');
await writeFile(installed, output);
console.log('Installed temporary acceptance copy; dist/ remains unchanged.');
