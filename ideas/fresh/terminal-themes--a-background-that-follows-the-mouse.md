# A background that follows the mouse

Order: 16012
From: the ideas repo, `games/terminal-themes.md` (<https://github.com/TefMeister/mod-ideas/blob/main/games/terminal-themes.md>), copied 2026-10-01

`[raw]` · `[hard]` — ⚠️ not checked: the terminal's shaders are given the time and the window size,
and nothing has been found yet that tells them where the mouse is.

> "background that follows the mouse"

**What it'd take:** first find out whether Windows Terminal passes anything about the mouse to a
shader at all. If not, it needs a helper running beside the terminal, or it cannot be done this way.
