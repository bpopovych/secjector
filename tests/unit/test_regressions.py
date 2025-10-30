#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path


def main() -> None:
    text = Path("secrets.rsc").read_text()

    if ":local key [$helperUnquote [$helperTrim" not in text:
        raise SystemExit("routeros parser must unquote key tokens before use")

    if not re.search(r"\. \[\$helperEsc \$key\] \.", text):
        raise SystemExit("routeros map population must escape keys via $helperEsc")

    if '[:pick $line 0 3]="---"' not in text:
        raise SystemExit("routeros parser must ignore YAML document-start markers")

    # secretCleanup disabled in RouterOS 7.20.x (cannot :set :global functions)
    # Check that it's commented out
    if text.count('# :set OUT ($OUT . ":local secretCleanup do={') != 1:
        raise SystemExit("secretCleanup code should be commented out (found in uncommented form)")

    if '# secretCleanup() -> disable accessors' not in text:
        raise SystemExit("secretCleanup comment should explain RouterOS 7.20.x limitation")

    print("secrets.rsc regression guards: ok")


if __name__ == "__main__":
    main()
