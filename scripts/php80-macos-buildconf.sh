#!/usr/bin/env bash
set -euo pipefail

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# StaticPHP invokes this hook from its extracted php-src directory.
python3 "$scripts_dir/patch-php80-macos.py" "$PWD/Zend/zend_string.c"
exec ./buildconf --force
