param([ValidateSet('Open','Capture','Inspect','Windows','Click','DoubleClick','Focus','Resize')][string]$Action = 'Capture', [string]$TargetPath, [int]$StudioProcessId = 0, [int]$X = 0, [int]$Y = 0, [switch]$RevealOptic, [switch]$OpticWindow, [int]$PanelWidth = 800, [int]$PanelHeight = 740)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Text;
public static class OpticStudioWindow {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr value);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr handle, IntPtr insertAfter, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr handle);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT point);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint x, uint y, uint data, UIntPtr extra);
    public static bool Focus(IntPtr handle) {
        uint ignored; uint foreground = GetWindowThreadProcessId(GetForegroundWindow(), out ignored);
        uint current = GetCurrentThreadId();
        bool attached = foreground != current && AttachThreadInput(current, foreground, true);
        try { ShowWindow(handle, 9); BringWindowToTop(handle); SetForegroundWindow(handle); return GetForegroundWindow() == handle; }
        finally { if (attached) AttachThreadInput(current, foreground, false); }
    }
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder value, int count);
    delegate bool EnumCallback(IntPtr handle, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumCallback callback, IntPtr parameter);
    public static Dictionary<string, object>[] Windows(int processId) {
        var result = new List<Dictionary<string, object>>();
        EnumWindows((handle, unused) => {
            uint owner; GetWindowThreadProcessId(handle, out owner);
            if (owner == processId) { var name = new StringBuilder(512); GetWindowText(handle, name, 512); RECT rectangle; GetWindowRect(handle, out rectangle); result.Add(new Dictionary<string, object>{{"Handle",handle.ToInt64()},{"Title",name.ToString()},{"Width",rectangle.Right-rectangle.Left},{"Height",rectangle.Bottom-rectangle.Top},{"Visible",IsWindowVisible(handle)}}); }
            return true;
        }, IntPtr.Zero);
        return result.ToArray();
    }
}
'@
[void][OpticStudioWindow]::SetProcessDPIAware()
[void][OpticStudioWindow]::SetThreadDpiAwarenessContext([IntPtr]::new(-4))
$studioProcess = if ($StudioProcessId) { Get-Process -Id $StudioProcessId } else { Get-Process -Name RobloxStudioBeta | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1 }
if (-not $studioProcess) { throw 'No visible Roblox Studio window was found.' }
$windows = [OpticStudioWindow]::Windows($studioProcess.Id)
if ($Action -eq 'Windows') { $windows | ConvertTo-Json -Depth 3; exit }
$handle = $studioProcess.MainWindowHandle
if ($OpticWindow) {
    $opticHost = $windows | Where-Object { $_.Title -eq 'RobloxStudio' -and $_.Visible -and $_.Width -ge 480 -and $_.Width -le 1000 -and $_.Height -ge 440 } | Select-Object -First 1
    if (-not $opticHost) { throw 'A floating Optic panel was not found.' }
    $handle = [IntPtr]::new($opticHost.Handle)
}
if ($handle -eq [IntPtr]::Zero) {
    $found = $windows | Where-Object { $_.Title -like '*.rbxl* - Roblox Studio*' } | Select-Object -First 1
    if (-not $found) { $found = $windows | Where-Object { $_.Title -like '*Roblox Studio*' } | Select-Object -First 1 }
    if (-not $found) { throw 'The Studio main window was not found.' }
    $handle = [IntPtr]::new($found.Handle)
}
if ($Action -eq 'Inspect') {
    Add-Type -AssemblyName UIAutomationClient
    $element = [System.Windows.Automation.AutomationElement]::FromHandle($handle)
    $element.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition) | ForEach-Object {
        $current = $_.Current
        if ($current.Name) { [pscustomobject]@{ Name = $current.Name; Type = $current.ControlType.ProgrammaticName; Bounds = $current.BoundingRectangle.ToString() } }
    } | ConvertTo-Json -Depth 3
    exit
}
$focused = [OpticStudioWindow]::Focus($handle)
if ($Action -eq 'Resize') {
    [void][OpticStudioWindow]::SetWindowPos($handle, [IntPtr]::Zero, 0, 0, $PanelWidth, $PanelHeight, 22)
    Write-Output ('Panel resized to ' + $PanelWidth + ' x ' + $PanelHeight)
    exit
}
if ($Action -eq 'Focus') { Write-Output ('Focused: ' + $focused); exit }
if ($Action -eq 'Click' -or $Action -eq 'DoubleClick') {
    if (-not $focused) { throw 'Studio did not receive focus; no click was sent.' }
    $clickRect = New-Object OpticStudioWindow+RECT
    [void][OpticStudioWindow]::GetWindowRect($handle, [ref]$clickRect)
    if ($RevealOptic) {
        Add-Type -AssemblyName UIAutomationClient
        $automationRoot = [System.Windows.Automation.AutomationElement]::FromHandle($handle)
        $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::TabItem)
        $tab = $automationRoot.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition) | Where-Object { $_.Current.Name -like 'Optic*Profiler' } | Select-Object -First 1
        if ($tab) {
            $bounds = $tab.Current.BoundingRectangle
            [void][OpticStudioWindow]::SetCursorPos([int]($bounds.Left + $bounds.Width / 2), [int]($bounds.Top + [Math]::Min(70, $bounds.Height / 2)))
            Start-Sleep -Milliseconds 300
            [OpticStudioWindow]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
            [OpticStudioWindow]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
            Start-Sleep -Milliseconds 300
        }
    }
    [void][OpticStudioWindow]::SetCursorPos($clickRect.Left + $X, $clickRect.Top + $Y)
    Start-Sleep -Milliseconds 100
    $cursor = New-Object OpticStudioWindow+POINT
    [void][OpticStudioWindow]::GetCursorPos([ref]$cursor)
    Write-Output ('Window ' + $clickRect.Left + ',' + $clickRect.Top + ' Click ' + $cursor.X + ',' + $cursor.Y)
    [OpticStudioWindow]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
    [OpticStudioWindow]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
    if ($Action -eq 'DoubleClick') {
        Start-Sleep -Milliseconds 90
        [OpticStudioWindow]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
        [OpticStudioWindow]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
    }
    exit
}
if ($Action -eq 'Open') {
    if ([OpticStudioWindow]::GetForegroundWindow() -ne $handle) { throw 'Studio did not receive focus; no keys were sent.' }
    [System.Windows.Forms.SendKeys]::SendWait('^o')
    Start-Sleep -Milliseconds 800
    [System.Windows.Forms.SendKeys]::SendWait($TargetPath)
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    exit
}
$rectangle = New-Object OpticStudioWindow+RECT
[void][OpticStudioWindow]::GetWindowRect($handle, [ref]$rectangle)
$bitmap = New-Object System.Drawing.Bitmap(($rectangle.Right - $rectangle.Left), ($rectangle.Bottom - $rectangle.Top))
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
    $graphics.CopyFromScreen($rectangle.Left, $rectangle.Top, 0, 0, $bitmap.Size)
    $bitmap.Save($TargetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output $TargetPath
} finally { $graphics.Dispose(); $bitmap.Dispose() }
