#!/usr/bin/env bash
# rg-liferay.sh — fast search across large Liferay Portal source trees
# Compatible with macOS, Ubuntu, and WSL.
#
# Usage:
#   bash rg-liferay.sh [options] <pattern>
#
# The pattern must be the LAST argument (after all options).
#
# Options:
#   -d <dir>        Search root (default: current directory)
#   -t <type>       File type filter: java, xml, jsp, js, properties, gradle, bnd, yaml (default: all)
#   -l              List matching files only (no content)
#   -n <limit>      Max results (default: 40)
#   -i              Case-insensitive search
#   -w              Match whole words only
#   -m <module>     Restrict search to a specific module path (e.g. portal-kernel, modules/apps/journal)
#   -C <lines>      Context lines around each match (default: 2)
#   -h              Show this help
#
# Requires: ripgrep (rg). Falls back to grep -rn if rg is not installed.

set -eo pipefail

# --- defaults ----------------------------------------------------------------
SEARCH_DIR="."
FILE_TYPE=""
LIST_ONLY=false
MAX_RESULTS=40
CASE_FLAG=""
WORD_FLAG=""
MODULE_PATH=""
CONTEXT=2

usage() {
  sed -n '2,/^$/{ s/^# //; s/^#//; p }' "$0"
  exit 0
}

# --- parse options -----------------------------------------------------------
while getopts "d:t:ln:iwm:C:h" opt; do
  case "$opt" in
    d) SEARCH_DIR="$OPTARG" ;;
    t) FILE_TYPE="$OPTARG" ;;
    l) LIST_ONLY=true ;;
    n) MAX_RESULTS="$OPTARG" ;;
    i) CASE_FLAG="-i" ;;
    w) WORD_FLAG="-w" ;;
    m) MODULE_PATH="$OPTARG" ;;
    C) CONTEXT="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

PATTERN="${1:-}"
if [ -z "$PATTERN" ]; then
  echo "Error: search pattern required." >&2
  echo "Usage: bash rg-liferay.sh <pattern> [options]" >&2
  exit 1
fi

# --- resolve search target ---------------------------------------------------
TARGET="$SEARCH_DIR"
if [ -n "$MODULE_PATH" ]; then
  TARGET="$SEARCH_DIR/$MODULE_PATH"
  if [ ! -d "$TARGET" ]; then
    echo "Error: module path not found: $TARGET" >&2
    exit 1
  fi
fi

# --- Liferay-specific exclusions (build output, caches, generated code) ------
EXCLUDES=(
  # Build output
  "classes"
  "bin"
  "build"
  "tmp"
  "out"
  ".gradle"
  "build-cache"
  # Generated / vendored
  "node_modules"
  "node_modules_cache"
  ".npmbundler"
  "generated"
  # IDE and tool metadata
  ".idea"
  ".settings"
  ".project"
  ".classpath"
  ".vscode"
  # VCS
  ".git"
  # Test fixtures that produce noise
  "test-classes"
  "test-results"
  "test-coverage"
  # Liferay-specific build artifacts
  "liferay-theme.json"
  ".digest"
  # Binary / archive
  "*.jar"
  "*.war"
  "*.zip"
  "*.tar.gz"
  "*.class"
  "*.png"
  "*.jpg"
  "*.gif"
  "*.ico"
  "*.woff"
  "*.woff2"
  "*.ttf"
  "*.eot"
  "*.svg"
  "*.min.js"
  "*.min.css"
  "*.map"
)

# --- file-type mapping (bash 3.2 compatible — no associative arrays) ---------
type_globs() {
  case "$1" in
    java)       echo "*.java" ;;
    xml)        echo "*.xml" ;;
    jsp)        echo "*.jsp *.jspf" ;;
    js)         echo "*.js *.jsx *.ts *.tsx" ;;
    properties) echo "*.properties" ;;
    gradle)     echo "*.gradle *.gradle.kts" ;;
    bnd)        echo "bnd.bnd" ;;
    ftl)        echo "*.ftl" ;;
    css)        echo "*.css *.scss" ;;
    yaml)       echo "*.yaml *.yml" ;;
    *)          echo "" ;;
  esac
}
AVAILABLE_TYPES="java xml jsp js properties gradle bnd ftl css yaml"

# --- build command -----------------------------------------------------------
if command -v rg &>/dev/null; then
  # ---- ripgrep path --------------------------------------------------------
  CMD=(rg --no-heading --color=never)

  if [ "$LIST_ONLY" = true ]; then
    CMD+=(--files-with-matches)
  else
    CMD+=(-C "$CONTEXT")
  fi

  [ -n "$CASE_FLAG" ] && CMD+=("$CASE_FLAG")
  [ -n "$WORD_FLAG" ] && CMD+=("$WORD_FLAG")

  for excl in "${EXCLUDES[@]}"; do
    if [[ "$excl" == *.* && "$excl" == \** ]]; then
      CMD+=(--glob "!$excl")
    else
      CMD+=(--glob "!$excl/")
    fi
  done

  if [ -n "$FILE_TYPE" ]; then
    globs="$(type_globs "$FILE_TYPE")"
    if [ -z "$globs" ]; then
      echo "Error: unknown type '$FILE_TYPE'. Available: $AVAILABLE_TYPES" >&2
      exit 1
    fi
    for g in $globs; do
      CMD+=(--glob "$g")
    done
  fi

  CMD+=("$PATTERN" "$TARGET")

  "${CMD[@]}" 2>/dev/null | head -n "$MAX_RESULTS"

else
  # ---- grep fallback (slower but always available) -------------------------
  echo "[WARN] ripgrep (rg) not found — falling back to grep (slower on large repos)." >&2
  echo "[HINT] Install: brew install ripgrep (macOS) | apt install ripgrep (Ubuntu/WSL)" >&2
  echo "" >&2

  GREP_EXCLUDES=""
  for excl in "${EXCLUDES[@]}"; do
    if [[ "$excl" == *.* && "$excl" == \** ]]; then
      GREP_EXCLUDES="$GREP_EXCLUDES --exclude=$excl"
    else
      GREP_EXCLUDES="$GREP_EXCLUDES --exclude-dir=$excl"
    fi
  done

  INCLUDE=""
  if [ -n "$FILE_TYPE" ]; then
    globs="$(type_globs "$FILE_TYPE")"
    if [ -z "$globs" ]; then
      echo "Error: unknown type '$FILE_TYPE'. Available: $AVAILABLE_TYPES" >&2
      exit 1
    fi
    for g in $globs; do
      INCLUDE="$INCLUDE --include=$g"
    done
  fi

  FLAGS="-rn"
  [ -n "$CASE_FLAG" ] && FLAGS="${FLAGS}i"
  [ -n "$WORD_FLAG" ] && FLAGS="${FLAGS}w"
  [ "$LIST_ONLY" = true ] && FLAGS="${FLAGS}l"

  # shellcheck disable=SC2086
  grep $FLAGS $GREP_EXCLUDES $INCLUDE -C "$CONTEXT" "$PATTERN" "$TARGET" 2>/dev/null | head -n "$MAX_RESULTS"
fi

exit 0
