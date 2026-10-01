# Records the Windows Terminal window while a preview profile runs in a new tab.
#
#   .\record.ps1 -ProfileName "Preview: ocean" -OutDir frames\ocean -Seconds 38 -IntervalMs 50
#   .\record.ps1 -ProfileName "Preview: green-monitor" -OutDir frames\gm -Seconds 26 -IntervalMs 200 -KeepAll
#
# Without -KeepAll only frames that differ from the previous one are saved (for the ocean, which
# changes 5 times a second on its own clock); with it, every capture is saved on the fixed interval.
# Frames land in OutDir as u0000.png, u0001.png ... plus times.txt (frame number, milliseconds).
# The window is maximised first, so every clip has the same size.
param([string]$ProfileName, [string]$OutDir, [int]$Seconds = 30, [int]$IntervalMs = 100, [int]$SettleSec = 4, [switch]$KeepAll)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class PreviewWin {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("msvcrt.dll")] public static extern int memcmp(IntPtr a, IntPtr b, UIntPtr n);
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Rt, B; }
  public static int[] Rect(IntPtr h) { R r; GetWindowRect(h, out r); return new int[] { r.L, r.T, r.Rt - r.L, r.B - r.T }; }
}
"@
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path   # .NET saves relative paths against the process folder, not this one
Get-ChildItem $OutDir -Filter *.png | Remove-Item -Force
$h = [PreviewWin]::GetForegroundWindow()
[void][PreviewWin]::ShowWindow($h, 3)
Start-Process wt.exe -ArgumentList "-w 0 new-tab -p `"$ProfileName`""
Start-Sleep -Seconds $SettleSec
$rc = [PreviewWin]::Rect($h); $x = $rc[0]; $y = $rc[1]; $w = $rc[2]; $ht = $rc[3]
"recording $ProfileName from $x,$y ${w}x${ht}"
$fmt = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
$a = New-Object System.Drawing.Bitmap $w, $ht, $fmt
$b = New-Object System.Drawing.Bitmap $w, $ht, $fmt
$ga = [System.Drawing.Graphics]::FromImage($a)
$gb = [System.Drawing.Graphics]::FromImage($b)
$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $ht
$bytes = [UIntPtr]::new([uint64]($w * $ht * 4))
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$n = 0; $kept = 0; $cur = $a; $gcur = $ga; $prev = $null
$times = New-Object System.Collections.Generic.List[string]
while ($sw.ElapsedMilliseconds -lt $Seconds * 1000) {
  $wait = $n * $IntervalMs - $sw.ElapsedMilliseconds
  if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }
  $gcur.CopyFromScreen($x, $y, 0, 0, $cur.Size)
  $same = $false
  if (-not $KeepAll -and $prev -ne $null) {
    $da = $cur.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
    $db = $prev.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $fmt)
    $same = ([PreviewWin]::memcmp($da.Scan0, $db.Scan0, $bytes) -eq 0)
    $cur.UnlockBits($da); $prev.UnlockBits($db)
  }
  if (-not $same) {
    $cur.Save((Join-Path $OutDir ("u{0:D4}.png" -f $kept)), [System.Drawing.Imaging.ImageFormat]::Png)
    $times.Add("$kept $($sw.ElapsedMilliseconds)")
    $kept++
    $prev = $cur
    if ($cur -eq $a) { $cur = $b; $gcur = $gb } else { $cur = $a; $gcur = $ga }
  }
  $n++
}
$times | Set-Content (Join-Path $OutDir "times.txt")
"done: $n captures, $kept frames saved, in $($sw.ElapsedMilliseconds) ms"
