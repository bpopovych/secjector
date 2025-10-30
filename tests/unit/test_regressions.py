#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path


def main() -> None:
    text = Path("secrets.rsc").read_text()

    if ":local key [$__unquote [$__trim" not in text:
        raise SystemExit("routeros parser must unquote key tokens before use")

    if not re.search(r"\. \[\$__esc \$key\] \.", text):
        raise SystemExit("routeros map population must escape keys via $__esc")

    if '[:pick $line 0 3]="---"' not in text:
        raise SystemExit("routeros parser must ignore YAML document-start markers")

    token = ':set OUT ($OUT . ":local secret_cleanup do={ '
    start = text.find(token)
    if start == -1:
        raise SystemExit("unable to locate secret_cleanup helper body")

    segment = text[start + len(token):]
    end = segment.find(';\\n")')
    if end == -1:
        raise SystemExit("unable to locate end of secret_cleanup helper")

    cleanup_body = segment[:end]
    for helper in ("secret", "secret_has", "secret_require", "secret_cleanup"):
        if f":set {helper} do={{" not in cleanup_body:
            raise SystemExit(f"secret_cleanup must rebind {helper} with :set")

    if ":local secret do={" in cleanup_body:
        raise SystemExit("secret_cleanup must not redeclare helpers with :local")

    print("secrets.rsc regression guards: ok")


if __name__ == "__main__":
    main()
