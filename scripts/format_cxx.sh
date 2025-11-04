#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       format_cxx.sh
# \brief      Format staged C/C++ files with clang-format and re-stage them.
# \author     Kawanami
# \version    1.0
# \date       26/10/2025
#
# \details
#   Finds files currently staged in Git whose extensions match common C/C++
#   suffixes and applies `clang-format -i` to them. Successfully formatted
#   files are re-staged to keep the index in sync.
#
# \remarks
#   - Operates only on **staged** files (ACMR filter).
#   - Requires `clang-format` to be available in PATH.
#
# \section format_cxx_sh_version_history Version history
# | Version | Date       | Author   | Description         |
# |:-------:|:----------:|:---------|:--------------------|
# | 1.0     | 26/10/2025 | Kawanami | Initial version.    |
# ********************************************************************************
# */

set -euo pipefail

# Format only staged C/C++ files and re-stage them.
EXTS="c cc cpp cxx h hh hpp hxx"

mapfile -t CANDIDATES < <(git diff --cached --name-only --diff-filter=ACMR || true)
FILES=()
for f in "${CANDIDATES[@]}"; do
  [[ -f "$f" ]] || continue
  ext="${f##*.}"
  for e in $EXTS; do
    if [[ "$ext" == "$e" ]]; then
      FILES+=("$f")
      break
    fi
  done
done

if (( ${#FILES[@]} == 0 )); then
  echo "No staged C/C++ files to format."
  exit 0
fi

clang-format -i -style=file:scripts/clang-format.flags "${FILES[@]}"
