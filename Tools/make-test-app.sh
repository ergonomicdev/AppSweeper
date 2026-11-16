#!/bin/bash
# Creates a dummy app "SweepTestDummy" plus realistic leftovers, to exercise AppSweeper.
# Usage: Tools/make-test-app.sh [create|verify|clean] [--system]
#   create  build the .app (default: ~/Desktop, override with DEST=dir) and create leftovers
#   verify  list which leftovers (and the app) still exist; exit 1 if any remain
#   clean   remove everything this script created
#   --system  also use /Library locations (asks for sudo)
# Only paths containing the dummy bundle id / name are ever touched.
set -u
BID="com.example.sweeptestdummy"
NAME="SweepTestDummy"
TEAM="ABCDE12345"
DEST="${DEST:-$HOME/Desktop}"
APP="$DEST/$NAME.app"
L="$HOME/Library"
CMD="${1:-create}"; SYSTEM=0
[ "${2:-}" = "--system" ] && SYSTEM=1

user_paths() { cat <<P
$L/Application Support/$NAME
$L/Caches/$BID
$L/Preferences/$BID.plist
$L/Containers/$BID
$L/Group Containers/$TEAM.$BID
$L/Logs/$NAME
$L/Saved Application State/$BID.savedState
$L/LaunchAgents/$BID.helper.plist
$L/WebKit/$BID
$L/HTTPStorages/$BID
$L/Cookies/$BID.binarycookies
P
}
system_paths() { cat <<P
/Library/Application Support/$NAME
/Library/Caches/$BID
/Library/Preferences/$BID.plist
/Library/LaunchDaemons/$BID.helper.plist
P
}
all_paths() { user_paths; [ $SYSTEM = 1 ] && system_paths; }

make_one() { # $1=path $2=use sudo
  local p="$1" sx="$2"
  case "$p" in *"$BID"*|*"$NAME"*) ;; *) echo "refusing $p"; return;; esac
  case "$p" in
    *.plist|*.binarycookies) $sx mkdir -p "$(dirname "$p")" && echo "dummy $NAME" | $sx tee "$p" >/dev/null ;;
    *) $sx mkdir -p "$p" && head -c 65536 /dev/urandom | $sx tee "$p/dummy.dat" >/dev/null ;;
  esac || echo "WARN: could not create $p (Full Disk Access needed for Terminal?)"
}

verify() {
  local left=0
  [ -e "$APP" ] && { echo "REMAINS  $APP"; left=1; }
  while IFS= read -r p; do [ -e "$p" ] && { echo "REMAINS  $p"; left=1; }; done < <(all_paths)
  # also catch anything else matching in the standard folders
  [ $left = 0 ] && echo "All clean: no leftovers found."
  return $left
}

case "$CMD" in
create)
  rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
  printf '#!/bin/sh\nexec /usr/bin/true\n' > "$APP/Contents/MacOS/$NAME"; chmod +x "$APP/Contents/MacOS/$NAME"
  cat > "$APP/Contents/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$BID</string>
<key>CFBundleName</key><string>$NAME</string>
<key>CFBundleExecutable</key><string>$NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
</dict></plist>
P
  codesign --force --sign - "$APP" 2>&1 | tail -1
  while IFS= read -r p; do make_one "$p" ""; done < <(user_paths)
  [ $SYSTEM = 1 ] && while IFS= read -r p; do make_one "$p" sudo; done < <(system_paths)
  echo "Created $APP and leftovers:"; verify ;;
verify) verify ;;
clean)
  rm -rf "$APP"
  while IFS= read -r p; do case "$p" in *"$BID"*|*"$NAME"*) rm -rf "$p";; esac; done < <(user_paths)
  [ $SYSTEM = 1 ] && while IFS= read -r p; do case "$p" in *"$BID"*|*"$NAME"*) sudo rm -rf "$p";; esac; done < <(system_paths)
  verify ;;
*) sed -n '2,8p' "$0"; exit 2 ;;
esac
