#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
php_version="${1:-8.0}"
if [[ ! "$php_version" =~ ^8\.[0-5](\.[0-9]+)?$ ]]; then
  echo "Usage: bash scripts/build.sh <PHP version, e.g. 8.0 or 8.5.8>" >&2
  exit 2
fi

case "$(uname -s)" in
  Linux) build_os=linux ;;
  Darwin) build_os=macos ;;
  *) echo "Builds require Linux or macOS." >&2; exit 2 ;;
esac
case "$(uname -m)" in
  x86_64) build_arch=x86_64 ;;
  aarch64|arm64) build_arch=aarch64 ;;
  *) echo "Unsupported CPU architecture: $(uname -m)" >&2; exit 2 ;;
esac
platform="${build_os}-${build_arch}"
build_dir="${BUILD_DIR:-$repo_dir/.build/$php_version-$platform}"
mkdir -p "$build_dir"
cd "$build_dir"
build_dir="$PWD"
mkdir -p log dist
echo "Building PHP $php_version (CLI and FPM) in $build_dir"
echo "Logs: $build_dir/log and $build_dir/console.log"

# Keep downloaded tools, sources, and compiled dependencies between local runs.
spc_bin="${SPC_BIN:-$build_dir/spc}"
if [[ ! -x "$spc_bin" || "${SPC_REFRESH:-0}" == 1 ]]; then
  curl --fail --location --silent --show-error \
    "${SPC_URL:-https://dl.static-php.dev/v3/spc-bin/nightly/spc-$platform}" \
    --output "$spc_bin.download"
  chmod +x "$spc_bin.download"
  mv "$spc_bin.download" "$spc_bin"
fi

if [[ "$build_os" == macos ]]; then
  if ! command -v brew >/dev/null; then
    echo "Install Homebrew and the Xcode command line tools before building on macOS." >&2
    exit 2
  fi
  brew list pkgconf >/dev/null 2>&1 || brew install pkgconf
  mkdir -p buildroot/bin buildroot/lib/pkgconfig
  ln -sf "$(brew --prefix pkgconf)/bin/pkgconf" buildroot/bin/pkg-config
  export PKG_CONFIG_PATH="$build_dir/buildroot/lib/pkgconfig"
  export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
  export SPC_CMD_VAR_PHP_MAKE_EXTRA_LDFLAGS="-framework SystemConfiguration -framework CoreFoundation -framework CoreServices"
else
  # Doctor searches buildroot/bin and pkgroot/bin, not the system PATH.
  # Use Ubuntu's installed tool instead of bootstrapping it before Zig is ready.
  pkg_config_bin="$(command -v pkg-config || command -v pkgconf || true)"
  if [[ -z "$pkg_config_bin" ]]; then
    echo "Install pkg-config before building (Ubuntu: apt-get update && apt-get install -y pkg-config)." >&2
    exit 2
  fi
  mkdir -p buildroot/bin buildroot/lib/pkgconfig
  ln -sf "$pkg_config_bin" buildroot/bin/pkg-config
  # Keep host library metadata out of the static dependency build.
  export PKG_CONFIG_PATH="$build_dir/buildroot/lib/pkgconfig"
  export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
fi

sed "s/^php-version:.*/php-version: \"$php_version\"/" "$repo_dir/craft.yml" > craft.yml
spc_extra_php_vars="${SPC_EXTRA_PHP_VARS:-}"
if [[ "$php_version" == 8.0 || "$php_version" == 8.0.* ]]; then
  # Protobuf's current sources use Zend macros unavailable in PHP 8.0.
  sed 's/,protobuf,/,/' craft.yml > craft-local.yml
  mv craft-local.yml craft.yml
  # Current libxml2 headers no longer define PHP 8.0's unused-parameter marker.
  spc_extra_php_vars="$spc_extra_php_vars CPPFLAGS=\"-I$build_dir/buildroot/include -DATTRIBUTE_UNUSED=\""
  # intl's ICU_CXXFLAGS follows PHP 8.0's hardcoded -std=c++11.
  spc_extra_php_vars="$spc_extra_php_vars ICU_CXXFLAGS=-std=c++17"
fi
if [[ "$build_os" == macos && "$php_version" =~ ^8\.[0-3](\.|$) ]]; then
  # Older PHP's configure probe links -lpq without its static dependencies.
  spc_extra_php_vars="$spc_extra_php_vars ac_cv_lib_pq_PQlibVersion=yes"
fi
export SPC_EXTRA_PHP_VARS="${spc_extra_php_vars# }"

build_php() {
  if [[ "${SKIP_DOCTOR:-0}" != 1 ]]; then
    "$spc_bin" doctor --auto-fix
  fi
  "$spc_bin" craft -v
}
# pipefail preserves build failures while retaining complete console output.
build_php 2>&1 | tee console.log

php_full_version="$(buildroot/bin/php -r 'echo PHP_VERSION;')"
[[ "$php_full_version" == "$php_version" || "$php_full_version" == "$php_version."* ]]
cli_name="php-$php_full_version-cli-$platform"
fpm_name="php-$php_full_version-fpm-$platform"
install -m 0755 buildroot/bin/php "dist/$cli_name"
install -m 0755 buildroot/bin/php-fpm "dist/$fpm_name"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "cli_name=$cli_name" >> "$GITHUB_OUTPUT"
  echo "fpm_name=$fpm_name" >> "$GITHUB_OUTPUT"
fi
echo "Built $build_dir/dist/$cli_name"
echo "Built $build_dir/dist/$fpm_name"
