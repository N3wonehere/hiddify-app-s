#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_dir="$(cd "$script_dir/.." && pwd)"

"$script_dir/prepare_custom_core.sh"
(
  cd "$repository_dir/hiddify-core"
  go test github.com/sagernet/sing/common/auth
  go test ./v2/config
)
make -C "$repository_dir/hiddify-core" android
mkdir -p "$repository_dir/android/app/libs"
cp "$repository_dir/hiddify-core/bin/hiddify-core.aar" "$repository_dir/android/app/libs/"
