#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       format_hdl.sh
# \brief      Format Verilog/SystemVerilog sources deterministically with Verible.
# \author     Kawanami
# \version    1.0
# \date       26/10/2025
#
# \details
#   Discovers repository-tracked HDL sources (*.sv, *.svh, *.v) and formats them
#   in-place using `verible-verilog-format` with the project’s flagfile.
#
# \remarks
#   - Requires `verible-verilog-format` to be available (invoked via ./scripts/).
#   - Uses `.verible-format` for consistent style across the repo.
#
# \section format_hdl_sh_version_history Version history
# | Version | Date       | Author   | Description      |
# |:-------:|:----------:|:---------|:-----------------|
# | 1.0     | 26/10/2025 | Kawanami | Initial version. |
# ********************************************************************************
# */

set -euo pipefail
# Format all Verilog/SystemVerilog sources deterministically.
# Requires: verible-verilog-format in PATH.

mapfile -t FILES < <(git ls-files '*.sv' '*.svh' '*.v')
if (( ${#FILES[@]} == 0 )); then
  echo "No Verilog/SystemVerilog files to format."
  exit 0
fi

./scripts/verible-verilog-format --flagfile=./scripts/verible_format.flags --inplace "${FILES[@]}"
