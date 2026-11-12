#!/usr/bin/env python3
# Capture the virtual display to a PNG: tools/vdisplay/shot.py out.png
import os, struct, subprocess, sys
from PIL import Image

display = os.environ.get("VDISPLAY", ":99")
raw = subprocess.run(["xwd", "-root", "-silent", "-display", display], capture_output=True, check=True).stdout
hdr = struct.unpack(">25I", raw[:100])
header_size, width, height = hdr[0], hdr[4], hdr[5]
bits_per_pixel, bytes_per_line, ncolors = hdr[11], hdr[12], hdr[19]
assert bits_per_pixel == 32, bits_per_pixel
offset = header_size + ncolors * 12
img = Image.frombuffer("RGBX", (width, height), raw[offset:offset + bytes_per_line * height], "raw", "BGRX", bytes_per_line, 1)
img.convert("RGB").save(sys.argv[1])
print(sys.argv[1], width, height)
