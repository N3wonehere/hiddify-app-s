#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_dir="$(cd "$script_dir/.." && pwd)"
core_dir="$repository_dir/hiddify-core"
core_patch="$repository_dir/patches/hiddify-core-lan-auth.patch"
sing_patch="$repository_dir/patches/sing-lan-auth.patch"
sing_box_patch="$repository_dir/patches/hiddify-sing-box-compat.patch"

apply_patch_once() {
  local target_dir="$1"
  local patch_file="$2"

  if (cd "$target_dir" && git apply --reverse --check "$patch_file" >/dev/null 2>&1); then
    return
  fi
  (cd "$target_dir" && git apply --check "$patch_file")
  (cd "$target_dir" && git apply "$patch_file")
}

if [[ ! -f "$core_dir/go.mod" ]]; then
  echo "hiddify-core is missing; initialize recursive submodules first" >&2
  exit 1
fi

apply_patch_once "$core_dir" "$core_patch"
apply_patch_once "$core_dir/hiddify-sing-box" "$sing_box_patch"

sing_version="$(sed -n 's/^[[:space:]]*github.com\/sagernet\/sing[[:space:]]\+\([^[:space:]]\+\)$/\1/p' "$core_dir/go.mod")"
if [[ -z "$sing_version" ]]; then
  echo "unable to resolve github.com/sagernet/sing version" >&2
  exit 1
fi

sing_module_json="$(cd "$core_dir" && go mod download -json "github.com/sagernet/sing@$sing_version")"
sing_module_dir="$(printf '%s\n' "$sing_module_json" | sed -n 's/^[[:space:]]*"Dir": "\(.*\)",$/\1/p')"
if [[ -z "$sing_module_dir" || ! -d "$sing_module_dir/common/auth" ]]; then
  echo "unable to locate downloaded github.com/sagernet/sing module" >&2
  exit 1
fi

chmod u+w \
  "$sing_module_dir/common/auth" \
  "$sing_module_dir/common/auth/auth.go" \
  "$sing_module_dir/protocol/http/handshake.go" \
  "$sing_module_dir/protocol/socks/handshake.go"
apply_patch_once "$sing_module_dir" "$sing_patch"
