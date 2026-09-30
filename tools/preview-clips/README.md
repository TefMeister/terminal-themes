# Recording the preview clips

Every clip in `preview/` is one exact loop: its last frame runs straight into its first. This is
how they are made, so a new style gets a clip the same way.

**The idea.** A style either repeats by itself or can be made to. The two green monitors repeat
every 9 seconds (the rolling light), so their clips are 18 seconds long. The scanlines style never
changes, so its clip loops on the typing alone. The aquarium never repeats in the terminal, but its
shader has a loop mode (`LOOP_SECONDS`) that makes every movement repeat exactly that often, used only
while recording. In the typing clips the screen is blank at the start and cleared again just before
the end, so the join lands on an empty screen; the aquarium's text simply stays put.

**Steps** (Windows Terminal maximised on a 3440x1440 screen; other sizes need the crop numbers in
`make-loop.py` changed):

1. `python add-profiles.py add` puts four "Preview: ..." profiles into the terminal's settings (backed
   up first) and writes the loop-mode copy of the aquarium shader next to this file.
2. Record each style. The aquarium is saved as unique frames, because it changes on its own clock;
   the others on a fixed interval:

   ```powershell
   .\record.ps1 -ProfileName "Preview: aquarium" -OutDir frames\aquarium -Seconds 38 -IntervalMs 50
   .\record.ps1 -ProfileName "Preview: green-monitor-starburst" -OutDir frames\starburst -Seconds 26 -IntervalMs 100 -SettleSec 1 -KeepAll
   .\record.ps1 -ProfileName "Preview: green-monitor" -OutDir frames\green-monitor -Seconds 26 -IntervalMs 200 -SettleSec 1 -KeepAll
   .\record.ps1 -ProfileName "Preview: sharp-scanlines" -OutDir frames\scanlines -Seconds 20 -IntervalMs 100 -SettleSec 1 -KeepAll
   ```

3. Cut each recording to one loop and encode it. The script finds the frame where the loop closes
   best and says how many pixels still differ (0 for the aquarium):

   ```
   python make-loop.py frames\aquarium ..\..\preview\aquarium.gif --period 160 --fps 5
   python make-loop.py frames\starburst ..\..\preview\green-monitor-starburst.gif --period 180 --fps 10
   python make-loop.py frames\green-monitor ..\..\preview\green-monitor.gif --period 90 --fps 5
   python make-loop.py frames\scanlines ..\..\preview\sharp-scanlines.gif --period 120 --fps 10 --native --dither none
   ```

4. `python add-profiles.py remove` takes the profiles out again and checks the settings file is byte
   for byte as it was.

The sample lines the clips show are in `sample-text.py`. `frames/` is ignored by git.
