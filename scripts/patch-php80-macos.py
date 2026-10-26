#!/usr/bin/env python3
"""Backport PHP GH-16348 to the PHP 8.0 x86_64 string comparison routine.

Upstream: php/php-src commit 806d2e073c1fe67dfe3c5791f4483f44dd991b28.
Numeric local labels prevent Apple's toolchain from merging assembly blocks
across functions. Only the x86_64 implementation is changed here.
"""

import sys
from pathlib import Path


def patch(path):
    source = path.read_text()
    start = source.index(
        "#elif defined(__GNUC__) && defined(__x86_64__) && !defined(__ILP32__)"
    )
    end = source.index("#ifdef HAVE_VALGRIND", start)
    original = source[start:end]
    updated = original
    replacements = {
        "char *ptr = ZSTR_VAL(s1);": "const char *ptr = ZSTR_VAL(s1);",
        "size_t delta = (char*)s2 - (char*)s1;":
            "uintptr_t delta = (uintptr_t) s2 - (uintptr_t) s1;",
        ".LL0%=:": "0:",
        ".LL1%=:": "1:",
        ".LL2%=:": "2:",
        ".LL3%=:": "3:",
        "jne .LL1%=": "jne 1f",
        "ja .LL0%=": "ja 0b",
        "jmp .LL3%=": "jmp 3f",
        "jb .LL2%=": "jb 2f",
    }
    if ".LL" not in original and "uintptr_t delta =" in original:
        print("PHP 8.0 macOS Intel assembly fix already applied.")
        return
    for old, new in replacements.items():
        if old not in updated:
            raise RuntimeError("Unexpected PHP source; missing: " + old)
        updated = updated.replace(old, new)
    if ".LL" in updated:
        raise RuntimeError("Unexpected assembly label remains after patching")
    path.write_text(source[:start] + updated + source[end:])
    print("Applied PHP GH-16348 assembly fix for macOS Intel.")


if __name__ == "__main__":
    patch(Path(sys.argv[1]))
