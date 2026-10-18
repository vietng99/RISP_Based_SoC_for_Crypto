#!/usr/bin/env bash
# Fetch the third-party RTL this folder needs, at the commits pinned in VERSIONS:
#   axi           pulp-platform/axi           v0.39.11  (axi_lite_xbar interconnect)
#   common_cells  pulp-platform/common_cells  v1.39.0
#   cva6          openhwgroup/cva6            v5.3.0    (only for the CVA6 SoC; pass --cva6)
# None of them is stored in this repository; flist/*.f expect them under third_party/.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

fetch() {  # name url commit [submodule paths...]
    local name="$1" url="$2" commit="$3"; shift 3
    local dest="$here/$name"
    if [ -d "$dest/.git" ] && [ "$(git -C "$dest" rev-parse HEAD)" = "$commit" ]; then
        echo "$name already at $commit"; return
    fi
    if [ -e "$dest" ]; then
        echo "$name: $dest exists and is not a clone at $commit; remove it to fetch" >&2; exit 1
    fi
    git clone --quiet "$url" "$dest"
    git -C "$dest" checkout --quiet "$commit"
    for sub in "$@"; do
        git -C "$dest" submodule update --init --quiet "$sub"
    done
    echo "$name at $(git -C "$dest" rev-parse HEAD)"
}

fetch axi https://github.com/pulp-platform/axi 42ca270ebd8bbbc1c64ddc0ca712e722eb9e3f06
fetch common_cells https://github.com/pulp-platform/common_cells 9ca8a7655f741e7dd5736669a20a301325194c28
if [ "${1:-}" = "--cva6" ]; then
    fetch cva6 https://github.com/openhwgroup/cva6 2ef1c1b1fca419354920c5487293bc605294904e \
        core/cvfpu core/cache_subsystem/hpdcache
    git -C "$here/cva6/core/cvfpu" submodule update --init --quiet src/fpu_div_sqrt_mvp
fi
