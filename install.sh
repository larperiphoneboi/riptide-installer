#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Riptide terminal palette — muted and flat, no neon.
DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'
ACCENT='\033[38;5;110m'   # steel blue — the Riptide accent
OKC='\033[38;5;114m'      # soft green
BADC='\033[38;5;203m'     # soft red
WARNC='\033[38;5;179m'    # soft amber
GREEN="$OKC"; RED="$BADC"; YELLOW="$WARNC"; CYAN="$ACCENT"; MAGENTA="$ACCENT"; BLUE="$ACCENT"
# Status marks — deliberately not the usual check/cross/arrow trio.
CHECK="${OKC}✓${NC}"; CROSS="${BADC}✕${NC}"; INFO="${DIM}›${NC}"; WARN="${WARNC}!${NC}"
GUT='  '                   # every line shares this left gutter
RULE_W=52                  # hairline width

RIPTIDE_VERSION="1.0.31"
# What this is: the Riptide app bundle (the editor GUI plus the executor
# dylib), zipped. It is hosted on an anonymous file host so the download link
# stays private to this group — it is not malware. The zip is checksummed by
# PAYLOAD_MD5 below, and that check runs before anything is installed.
PAYLOAD_URL="https://files.catbox.moe/236adn.zip"
PAYLOAD_MD5="f654cb099111f8220f3dc350562b7160"
RBX_VERSION="version-5b15515e80624095"
RBX_PLAYER="0.738.0.7381393"
RBX_URL="https://setup.rbxcdn.com/mac/${RBX_VERSION}-RobloxPlayer.zip"
RBX_MD5="200789e817ab4ed6fbe45632db2bcbdb"
INSTALLER_URL="https://raw.githubusercontent.com/larperiphoneboi/riptide-installer/main/install.sh"

if [ -w "/Applications" ]; then
  APP_DIR="/Applications"
else
  APP_DIR="$HOME/Applications"
fi

# A hairline. Built with printf + tr rather than a character-append loop:
# bash mangles multi-byte box-drawing characters when it grows a string, so we
# let printf lay down the width and tr swap the glyph.
rule() {
  local n="${1:-${RULE_W:-52}}"
  printf "%${n}s" "" | tr ' ' '─'
}

# A section is a title with a hairline under it — no arrows, no boxes.
section() {
  echo
  echo -e "${GUT}${ACCENT}${1}${NC}"
  echo -e "${GUT}${DIM}$(rule)${NC}"
}

run_step() {
  local msg="$1"; shift
  echo -ne "${GUT}${DIM}·${NC} ${msg}\r"
  if "$@"; then
    printf "\r\033[K${GUT}${OKC}✓${NC} ${msg}\n"
  else
    printf "\r\033[K${GUT}${BADC}✕${NC} ${msg}\n"
    exit 1
  fi
}

verify_md5() {
  local got
  got="$(/sbin/md5 -q "$1" 2>/dev/null || md5 -q "$1")"
  [ "$got" = "$2" ] || { echo -e "${GUT}${BADC}✕${NC} $3 failed the md5 check (got $got, expected $2)"; exit 1; }
}
export -f verify_md5

banner() {
  clear
  echo
  echo -e "${GUT}${BOLD}${ACCENT}R I P T I D E${NC}  ${DIM}v${RIPTIDE_VERSION}${NC}"
  echo -e "${GUT}${DIM}$(rule)${NC}"
  echo
  echo -e "${GUT}${ACCENT}The newest macOS premium executor${NC}"
  echo -e "${GUT}${DIM}built for macOS, nothing else${NC}"
  echo -e "${GUT}${DIM}not affiliated with Roblox · educational proof of concept${NC}"
  echo
}

surf_report() {
  echo
  echo -e "${GUT}${OKC}✓${NC} ${BOLD}Riptide ${RIPTIDE_VERSION} installed${NC}"
  echo -e "${GUT}${DIM}$(rule)${NC}"
  echo -e "${GUT}${DIM}version${NC}   ${BOLD}$RIPTIDE_VERSION${NC}"
  echo -e "${GUT}${DIM}installed${NC} $APP_DIR/Riptide.app"
  echo -e "${GUT}${DIM}roblox${NC}    ${BOLD}pinned${NC} ${DIM}· injection ready${NC}"
  echo
}

do_uninstall() {
  banner
  section "Uninstalling Riptide"
  killall -9 RobloxCrashHandler RobloxMenuBar RobloxPlayer Roblox Riptide 2>/dev/null || true
  run_step "Removing Riptide.app" bash -c "
    rm -rf '$APP_DIR/Riptide.app' 2>/dev/null || sudo rm -rf '$APP_DIR/Riptide.app'
    [ ! -e '$APP_DIR/Riptide.app' ]
  "
  rm -rf "$HOME/Library/Application Support/Riptide" 2>/dev/null || true
  rm -f "$HOME/Library/Preferences/com.riptide.executor.gui.plist" 2>/dev/null || true
  echo
  echo -e "${GUT}${OKC}✓${NC} ${BOLD}Riptide has been removed.${NC}"
  echo -e "${GUT}${WARNC}!${NC} Roblox is untouched and still patched. Restore stock Roblox with:"
  echo "  curl -fsSL $INSTALLER_URL | bash"
}

case "${1:-}" in
  --uninstall|--remove)
    do_uninstall
    exit 0
    ;;
esac

main() {
  banner

  echo -e "${GUT}${DIM}installing into${NC} ${BOLD}$APP_DIR${NC}"

  TEMP="$(mktemp -d)"
  trap 'rm -rf "$TEMP"' EXIT

  section "Closing Roblox"
  run_step "Killing Roblox processes" bash -c \
    'killall -9 RobloxCrashHandler RobloxMenuBar RobloxPlayer Roblox 2>/dev/null || true'

  section "Removing previous installs"
  for target in "$APP_DIR/Roblox.app" "$APP_DIR/Riptide.app"; do
    [ -e "$target" ] || continue
    name="$(basename "$target")"
    rm -rf "$target" 2>/dev/null || true
    if [ -e "$target" ]; then
      echo -e "${GUT}${WARNC}!${NC} removing $name needs root…"
      sudo rm -rf "$target" 2>/dev/null || true
    fi
    if [ -e "$target" ]; then
      echo -e "${GUT}${BADC}✕${NC} could not remove $name — delete it by hand, then re-run"
      exit 1
    fi
    echo -e "${GUT}${OKC}✓${NC} removed $name"
  done

  section "Preparing Roblox $RBX_PLAYER"
  run_step "Downloading Roblox (~140 MB)" bash -c "
    curl -# -L '$RBX_URL' -o '$TEMP/Roblox.zip' &&
    verify_md5 '$TEMP/Roblox.zip' '$RBX_MD5' 'Roblox' &&
    unzip -oq '$TEMP/Roblox.zip' -d '$TEMP' &&
    rm -rf '$APP_DIR/Roblox.app' &&
    mv '$TEMP/RobloxPlayer.app' '$APP_DIR/Roblox.app' &&
    xattr -dr com.apple.quarantine '$APP_DIR/Roblox.app' &&
    codesign --remove-signature '$APP_DIR/Roblox.app/Contents/MacOS/RobloxPlayer'
  "

  section "Installing Riptide $RIPTIDE_VERSION"
  run_step "Downloading the Riptide payload" bash -c "
    curl -# -L '$PAYLOAD_URL' -o '$TEMP/Riptide.zip' &&
    verify_md5 '$TEMP/Riptide.zip' '$PAYLOAD_MD5' 'Riptide' &&
    unzip -oq '$TEMP/Riptide.zip' -d '$TEMP' &&
    rm -rf '$APP_DIR/Riptide.app' &&
    mv '$TEMP/Riptide.app' '$APP_DIR/Riptide.app' &&
    xattr -dr com.apple.quarantine '$APP_DIR/Riptide.app'
  "

  section "Patching RobloxPlayer"
  run_step "Injecting libRiptide.dylib" bash -c "
    rm -rf '$APP_DIR/Roblox.app/Contents/MacOS/RobloxPlayerInstaller.app' &&
    rm -rf '$APP_DIR/Roblox.app/Contents/MacOS/RobloxMenuBar.app' &&
    '$APP_DIR/Riptide.app/Contents/Resources/riptide-machopatch' \
        --binary '$APP_DIR/Roblox.app/Contents/MacOS/RobloxPlayer' \
        --dylib '$APP_DIR/Riptide.app/Contents/Resources/libRiptide.dylib' &&
    rm -f '$APP_DIR/Roblox.app/Contents/MacOS/RobloxPlayer.unix-backup' &&
    codesign --force -s - '$APP_DIR/Roblox.app/Contents/MacOS/RobloxPlayer'
  "

  section "Setting up the workspace"
  mkdir -p "$HOME/Documents/Riptide/workspace" "$HOME/Documents/Riptide/autoexec"
  echo -e "${GUT}${OKC}✓${NC} ~/Documents/Riptide/workspace + autoexec ready"

  section "Riptide AI (MCP assistant)"
  if command -v node >/dev/null 2>&1; then
    NODE_BIN="$(command -v node)"
    echo -e "${GUT}${OKC}✓${NC} Node runtime found ($NODE_BIN)"
    if [ -d "$APP_DIR/Riptide.app/Contents/Resources/ai" ]; then
      echo -e "${GUT}${OKC}✓${NC} AI bundle shipped inside the app — MCP server ready"
      echo -e "${GUT}${DIM}·${NC} The first macOS executor with an AI MCP. Connect it from the app:"
      echo -e "${GUT}${DIM}·${NC}   Settings → AI & MCP (Claude Desktop, Cursor, or any MCP client)."
    else
      echo -e "${WARN} Riptide.app has no Contents/Resources/ai — rebuild the payload so the"
      echo -e "${WARN} AI side is included (tools/build-ui.sh copies it when it is built)."
    fi
  else
    echo -e "${WARN} Node.js not found — the AI assistant and MCP server need it."
    echo -e "${WARN} Install it with:  brew install node"
  fi

  surf_report
  echo -e "${GUT}${DIM}update${NC}    ${DIM}curl -fsSL $INSTALLER_URL | bash${NC}"
  echo -e "${GUT}${DIM}uninstall${NC} ${DIM}bash install.sh --uninstall${NC}"

  open "$APP_DIR/Roblox.app"
  open "$APP_DIR/Riptide.app"
}

main "$@"