#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v verilator >/dev/null 2>&1; then
  echo "ERROR: Verilator not found. Please install verilator to run lint." >&2
  exit 2
fi

# Ensure build_info.vh exists so includes don't fail
if [ ! -f build_info.vh ]; then
cat <<'EOF' > build_info.vh
`define GIT_HASH   "unknown"
`define FW_TYPE    "SINGLE"
`define FW_C_SHA1  "none"
`define FW_A_SHA1  "none"
EOF
fi

SRC=(
  # Use our own top from rtl/ (picked up below). Avoid vendor mycore.sv to prevent duplicate 'emu'.
  # vendor/Template_MiSTer-master/mycore.sv
  # vendor/Template_MiSTer-master/sys/hps_io.sv
  vendor/Template_MiSTer-master/rtl/mycore.v
  vendor/Template_MiSTer-master/rtl/pll.v
  # vendor/Template_MiSTer-master/rtl/pll/pll_0002.v
  vendor/Template_MiSTer-master/rtl/lfsr.v
  tb/stubs/intel_ip_stub.v
  tb/stubs/altera_pll_stub.v
  tb/stubs/mister_stub.v
  tb/stubs/cos_stub.sv
  tb/stubs/pll_0002_stub.v
  tb/stubs/pll_hdmi_0002_stub.v
  tb/stubs/sync_fix_stub.sv
  tb/stubs/hq2x_stub.sv
)

# Optionally include custom project RTL if present
shopt -s nullglob
RTL_SV=(rtl/*.sv)
RTL_V=(rtl/*.v)
if (( ${#RTL_SV[@]} > 0 )); then SRC+=("${RTL_SV[@]}"); fi
if (( ${#RTL_V[@]} > 0 )); then SRC+=("${RTL_V[@]}"); fi
shopt -u nullglob

verilator --lint-only -sv \
  -DFORMAL \
  -Wall -Wno-fatal \
  -Wno-BLKANDNBLK \
  -Wno-DECLFILENAME -Wno-PINCONNECTEMPTY -Wno-UNDRIVEN -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
  -Wno-WIDTHEXPAND -Wno-ASSIGNDLY \
  -Itb/include -Ivendor/Template_MiSTer-master/sys -Ivendor/Template_MiSTer-master/rtl -Irtl \
  "${SRC[@]}"

echo "Verilator lint completed successfully."
