# Records ONE Windows Terminal window by asking that window to draw itself (PrintWindow), not by
# copying the screen, so whatever else is open on the screen can never end up in a frame.
#   .\record-window.ps1 -ProfileName "Preview: ocean" -OutDir frames\ocean -Seconds 42 -IntervalMs 200 -SettleSec 5
ecord-window.ps1 -ProfileName "Preview: ocean" -OutDir framesocean -Seconds 42 -IntervalMs 200 -SettleSec 5
param([string]$ProfileName, [string]$OutDir, [int]$Seconds = 5, [int]$IntervalMs = 200,
      [int]$Cols = 136, [int]$Rows = 47, [int]$SettleSec = 12)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class WinCap {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Rt, B; }
  public static IntPtr Find(string title) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      var c = new StringBuilder(256); GetClassName(h, c, 256);
      var t = new StringBuilder(512); GetWindowText(h, t, 512);
      if (IsWindowVisible(h) && c.ToString() == "CASCADIA_HOSTING_WINDOW_CLASS" && t.ToString() == title) { found = h; return false; }
      return true; }, IntPtr.Zero);
    return found;
  }
}
"@
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
Get-ChildItem $OutDir -Filter *.png | Remove-Item -Force
Start-Process wt.exe -ArgumentList "-w preview-clip --pos 40,40 --size $Cols,$Rows new-tab --title `"$ProfileName`" --suppressApplicationTitle -p `"$ProfileName`""
$h = [IntPtr]::Zero
for ($i = 0; $i -lt 100 -and $h -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 100; $h = [WinCap]::Find($ProfileName) }
if ($h -eq [IntPtr]::Zero) { "window not found"; exit 1 }
Start-Sleep -Seconds $SettleSec                     # the terminal builds the shader first
$r = New-Object WinCap+R; [void][WinCap]::GetWindowRect($h, [ref]$r)
$w = $r.Rt - $r.L; $ht = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$sw = [System.Diagnostics.Stopwatch]::StartNew(); $n = 0
while ($sw.ElapsedMilliseconds -lt $Seconds * 1000) {
  $wait = $n * $IntervalMs - $sw.ElapsedMilliseconds
  if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }
  $dc = $g.GetHdc()
  [void][WinCap]::PrintWindow($h, $dc, 2)            # 2 = PW_RENDERFULLCONTENT: includes the GPU-drawn part
  $g.ReleaseHdc($dc)
  $bmp.Save((Join-Path $OutDir ("u{0:D4}.png" -f $n)), [System.Drawing.Imaging.ImageFormat]::Png)
  $n++
}
[void][WinCap]::PostMessage($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
"captured $n frames ${w}x${ht}"
