"""Finds a node in a `uiautomator dump` by label and prints its center.

Usage: python3 ui.py dump.xml "Label" [exact|contains]
Flutter exposes semantics labels as content-desc (and sometimes text).
"""
import re
import sys
import xml.etree.ElementTree as ET

path, label = sys.argv[1], sys.argv[2]
mode = sys.argv[3] if len(sys.argv) > 3 else "exact"

for node in ET.parse(path).iter("node"):
    for attr in ("content-desc", "text"):
        value = node.get(attr) or ""
        first_line = value.split("\n")[0]
        if (mode == "exact" and label in (value, first_line)) or (
            mode == "contains" and label in value
        ):
            x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.get("bounds")))
            print((x1 + x2) // 2, (y1 + y2) // 2)
            sys.exit(0)
sys.exit(1)
