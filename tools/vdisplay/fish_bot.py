#!/usr/bin/env python3
# Plays the catch minigame on the virtual display: presses Space when the
# white cursor is inside the green zone. Open the boat screen first.
# Usage: tools/vdisplay/fish_bot.py seconds
import os, struct, subprocess, sys, time

DISPLAY = os.environ.get("VDISPLAY", ":99")
BAR_Y = 323


def bar_row():
    raw = subprocess.run(["xwd", "-root", "-silent", "-display", DISPLAY], capture_output=True, check=True).stdout
    hdr = struct.unpack(">25I", raw[:100])
    off = hdr[0] + hdr[19] * 12 + hdr[12] * BAR_Y
    line = raw[off:off + hdr[4] * 4]
    return [(line[i + 2], line[i + 1], line[i]) for i in range(0, len(line), 4)]


presses = 0
end = time.time() + float(sys.argv[1])
while time.time() < end:
    px = bar_row()
    green = [x for x, (r, g, b) in enumerate(px) if g > 150 and r < 120 and b < 120]
    white = [x for x, (r, g, b) in enumerate(px) if r > 230 and g > 230 and b > 230]
    if green and white:
        cursor = sum(white) / len(white)
        if min(green) + 4 <= cursor <= max(green) - 4:
            subprocess.run(["xdotool", "key", "space"], env={"DISPLAY": DISPLAY})
            presses += 1
            time.sleep(0.35)
print("presses in green:", presses)
