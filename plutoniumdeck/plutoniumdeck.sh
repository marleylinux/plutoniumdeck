#!/usr/bin/env bash
# plutoniumdeck/plutoniumdeck/plutoniumdeck.sh

set -Eeuo pipefail

# ----------------------------
# Styling (ported from marleyinstall.sh)
# ----------------------------
say() { printf '%s\n' "$*"; }
p() { printf '%s %s\n' "$1" "$2"; }

maybe_quit() {
  case "${1,,}" in
    quit|exit)
      say ""
      say "$BANNER_LINE"
      p "$UI_NOTE" "Exited installer."
      say "$BANNER_LINE"
      exit 0
      ;;
  esac
}

prompt_read() {
  local __varname="$1"
  local __prompt="$2"
  local __default="${3-}"
  local __val=""

  if [ -t 0 ]; then
    if ! read -r -p "$__prompt" __val; then __val=""; fi
  elif [ -r /dev/tty ]; then
    if ! read -r -p "$__prompt" __val < /dev/tty; then __val=""; fi
  else
    __val=""
  fi

  maybe_quit "$__val"

  if [ -z "$__val" ] && [ -n "$__default" ]; then
    __val="$__default"
  fi

  printf -v "$__varname" '%s' "$__val"
}

confirm() {
  local yn=""
  prompt_read yn "$1 [y/N] (or 'quit'): " ""
  case "$yn" in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

has_noto_emoji() {
  command -v pacman >/dev/null 2>&1 || return 1
  pacman -Q noto-fonts-emoji >/dev/null 2>&1
}

NOTO_PRESENT_AT_START=0
if has_noto_emoji; then NOTO_PRESENT_AT_START=1; fi

pick_ui() {
  if [ "${NO_EMOJI:-0}" = "1" ]; then
    USE_EMOJI=0
    return 0
  fi

  if [ "${NOTO_PRESENT_AT_START:-0}" = "1" ]; then
    USE_EMOJI=1
  else
    USE_EMOJI=0
  fi
}

pick_ui

if [ "${USE_EMOJI:-0}" = "1" ]; then
  UI_ML="🟪"
  UI_INFO="🟦"
  UI_NOTE="🟨"
  UI_OK="🟩"
  UI_ERR="🟥"

  INNER_LINE="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  BANNER_LINE="${UI_ML}${INNER_LINE}${UI_ML}"
  cat_line() { local box="${1:-$UI_ML}"; printf '%s%s%s\n' "$box" "$INNER_LINE" "$box"; }
else
  UI_ML="<ml>"
  UI_INFO="<info>"
  UI_NOTE="<note>"
  UI_OK="<ok>"
  UI_ERR="<error>"

  INNER_LINE="======================================================"
  BANNER_LINE="$INNER_LINE"
  cat_line() { printf '%s\n' "$INNER_LINE"; }
fi

section() {
  say ""
  say "$BANNER_LINE"
  p "$UI_ML" "$1"
  say "$BANNER_LINE"
}

tutorial() {
  section "Tutorial: Instructions"

  say ""
  cat_line "$UI_ML"
  p "$UI_ML" "After running the Plutonium installer, locate the torrent files in ~/wine/plutonium/callofduty/.
Open these torrents in qBittorrent (or your preferred client) and download them.
Once downloaded:
Copy T6dlc contents to the T6 folder.
Copy T5dlc contents to the T5 folder.

Place the main game files anywhere (Plutonium will prompt you to select the folder on first launch).
Recommended location: ~/wine/plutonium/callofduty/ for organization."
  p "$UI_ML" "Step 2: Configure Lutris Runners

In Lutris, setup both Spoofy and Plutonium. 

This is an example of the correct options to setup plutonium in lutris. Do this through the lutris GUI add game and manually install game.

  args: DXVK_ASYNC=1 PROTON_NO_FSYNC=1 PROTON_NO_ESYNC=1
  exe: /home/marley/wine/plutonium/plutonium.exe
  prefix: /home/marley/wine/plutonium/prefix
  working_dir: /home/marley/wine/plutonium
wine:
  version: any new Proton-GE

  This is an example of the correct options to setup spoofy in lutris. Do this through the lutris GUI add game and manually install game.

  game:
  args: --asroot
  exe: /home/marley/wine/plutonium/SecHex-Spoofy/SecHex-GUI.exe
  prefix: /home/marley/wine/plutonium/prefix
  working_dir: /home/marley/wine/plutonium/SecHex-Spoofy/
wine:
  version: any new Proton-GE

Select Spoofy in Lutris (only needed for Spoofy).
Click the Wine/Proton icon > Winetricks.
Select Default prefix.
Install the Windows component: dotnet6 (or dotnet6 if listed).
Close Winetricks."
  p "$UI_ML" "Step 4: Launch Sequence (Every Time)
The banned message on first Plutonium launch is normal (Plutonium banned legacy clients due to outdated anticheat).

Launch Spoofy from Lutris.
Click Spoof All (ignore any errors—they're expected).
Keep Spoofy running in the background.
Launch Plutonium from Lutris.
Select and load your desired CoD game (T4/T5/T6).
If logged out, simply log back in (normal behavior).


Repeat Step 4 every launch. Spoofy must be active to bypass the ban."
  cat_line "$UI_ML"

  section "Tutorial: plutoniumdeck copy layout"

  p "$UI_NOTE" "Tip: type 'quit' or 'exit' at ANY prompt to leave the script."
  p "$UI_NOTE" "For colored emoji boxes: install 'noto-fonts-emoji' and restart your GUI terminal."
  p "$UI_NOTE" "Emoji boxes usually will NOT work in a TTY (TERM=linux). This script falls back to ASCII tags."
  say ""

  p "$UI_NOTE" "What it creates:"
  p "$UI_NOTE" "  ~/wine/plutonium/prefix"
  say ""

  p "$UI_NOTE" "What it copies:"
  p "$UI_NOTE" "  callofduty/        -> ~/wine/plutonium/"
  p "$UI_NOTE" "  SecHex-Spoofy/     -> ~/wine/plutonium/"
  p "$UI_NOTE" "  plutonium.exe      -> ~/wine/plutonium/"
  say ""
}

# ----------------------------
# Copy logic (kept from previous version)
# ----------------------------
have_cmd() { command -v "$1" >/dev/null 2>&1; }

rsync_supports_mkpath() {
  have_cmd rsync || return 1
  rsync --help 2>/dev/null | grep -q -- '--mkpath'
}

DRY_RUN=0

copy_dir() {
  local src="$1"
  local dest_parent="$2"

  [[ -d "$src" ]] || { p "$UI_ERR" "Missing directory: $src"; exit 1; }
  mkdir -p "$dest_parent"

  if have_cmd rsync; then
    local -a opts=(-a)
    if [ "$DRY_RUN" = "1" ]; then opts+=(--dry-run); fi
    if rsync_supports_mkpath; then opts+=(--mkpath); fi
    rsync "${opts[@]}" "$src" "$dest_parent/"
  else
    if [ "$DRY_RUN" = "1" ]; then
      p "$UI_INFO" "DRY RUN: cp -a \"$src\" \"$dest_parent/\""
    else
      cp -a "$src" "$dest_parent/"
    fi
  fi
}

copy_file() {
  local src="$1"
  local dest_dir="$2"

  [[ -f "$src" ]] || { p "$UI_ERR" "Missing file: $src"; exit 1; }
  mkdir -p "$dest_dir"

  if have_cmd rsync; then
    local -a opts=(-a)
    if [ "$DRY_RUN" = "1" ]; then opts+=(--dry-run); fi
    if rsync_supports_mkpath; then opts+=(--mkpath); fi
    rsync "${opts[@]}" "$src" "$dest_dir/"
  else
    if [ "$DRY_RUN" = "1" ]; then
      p "$UI_INFO" "DRY RUN: cp -a \"$src\" \"$dest_dir/\""
    else
      cp -a "$src" "$dest_dir/"
    fi
  fi
}

copy_dir_contents() {
  local src_dir="$1"
  local dest_dir="$2"

  [[ -d "$src_dir" ]] || { p "$UI_ERR" "Missing directory: $src_dir"; exit 1; }
  mkdir -p "$dest_dir"

  if have_cmd rsync; then
    local -a opts=(-a)
    if [ "$DRY_RUN" = "1" ]; then opts+=(--dry-run); fi
    if rsync_supports_mkpath; then opts+=(--mkpath); fi
    rsync "${opts[@]}" "$src_dir"/ "$dest_dir"/
  else
    if [ "$DRY_RUN" = "1" ]; then
      p "$UI_INFO" "DRY RUN: cp -a \"$src_dir/.\" \"$dest_dir/\""
    else
      cp -a "$src_dir"/. "$dest_dir"/
    fi
  fi
}

usage() {
  say "Usage: $(basename "$0") [--yes] [--dry-run] [--no-emoji] [--tutorial]"
  say ""
  say "  --yes        Skip confirmation prompt"
  say "  --dry-run    Show what would be copied without writing changes"
  say "  --no-emoji   Force ASCII UI tags"
  say "  --tutorial   Print tutorial block"
}

YES=0

while [ "${1-}" != "" ]; do
  case "$1" in
    -y|--yes) YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-emoji) NO_EMOJI=1; USE_EMOJI=0 ;;
    --tutorial) tutorial; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) p "$UI_ERR" "Unknown arg: $1"; usage; exit 2 ;;
  esac
  shift
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ASSET_ROOT="$SCRIPT_DIR"
if [[ ! -d "$ASSET_ROOT/callofduty" ]] && [[ -d "$ASSET_ROOT/plutoniumdeck/callofduty" ]]; then
  ASSET_ROOT="$ASSET_ROOT/plutoniumdeck"
fi

SRC_COD="$ASSET_ROOT/callofduty"
SRC_SPOOFY="$ASSET_ROOT/SecHex-Spoofy"
SRC_EXE="$ASSET_ROOT/plutonium.exe"

DEST_WINE_BASE="$HOME/wine"
DEST_PLUTONIUM="$DEST_WINE_BASE/plutonium"
DEST_PREFIX="$DEST_PLUTONIUM/prefix"

section "PlutoniumDeck Installer"

p "$UI_INFO" "Script dir: $SCRIPT_DIR"
p "$UI_INFO" "Asset root: $ASSET_ROOT"
say ""

tutorial

if [ "$YES" != "1" ] && [ -t 0 -o -r /dev/tty ]; then
  if ! confirm "Proceed with copying files to your home directories?"; then
    p "$UI_NOTE" "Cancelled."
    exit 0
  fi
fi

p "$UI_INFO" "Creating folders..."
mkdir -p "$DEST_PREFIX"

p "$UI_INFO" "Copying Call of Duty folder -> $DEST_PLUTONIUM/"
copy_dir "$SRC_COD" "$DEST_PLUTONIUM"

p "$UI_INFO" "Copying SecHex-Spoofy folder -> $DEST_PLUTONIUM/"
copy_dir "$SRC_SPOOFY" "$DEST_PLUTONIUM"

p "$UI_INFO" "Copying plutonium.exe -> $DEST_PLUTONIUM/"
copy_file "$SRC_EXE" "$DEST_PLUTONIUM"

say ""
say "$BANNER_LINE"
p "$UI_OK" "Done."
p "$UI_OK" "Installed to: $DEST_PLUTONIUM"
say "$BANNER_LINE"

