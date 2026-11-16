#!/bin/bash
# Creates a zip of retroshare-backup with everything needed to run it on
# Windows: the exe, retroshare.dll/librnp.dll (qmake builds), Qt (DLLs +
# plugins) and the MSYS2 DLLs.
#
# Run it from the MSYS2 MINGW64 shell, or double-click make-zip.bat.
# Build the tool first (qmake or CMake, release build).

set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME_EXE="retroshare-backup.exe"

# Build folder: argument, qmake (release/) or CMake (build/)
RELEASE=""
for d in "$1" "$HERE/release" "$HERE/build" "$HERE/build/release" "$HERE/build/Release"; do
	[ -n "$d" ] && [ -f "$d/$NAME_EXE" ] && { RELEASE="$(cd "$d" && pwd)"; break; }
done
DIST="$HERE/dist"
NAME="retroshare-backup"
OUT="$DIST/$NAME"
ZIP="$DIST/$NAME-$(date +%Y%m%d).zip"

fail() { echo; echo "ERROR: $*"; exit 1; }

[ -n "$RELEASE" ] || fail "$NAME_EXE not found in release/ (qmake) or build/ (CMake). Build the tool first, or give the build folder: make-zip.sh <folder>"
echo "== Using $RELEASE/$NAME_EXE"

command -v objdump >/dev/null || fail "objdump not found. Install binutils: pacman -S mingw-w64-x86_64-binutils"

echo "== Collecting files in $OUT"
rm -rf "$OUT"
mkdir -p "$OUT"

# 1. the tool and RetroShare's own DLLs (the ones it was built with)
cp "$RELEASE/$NAME.exe" "$OUT/"
# (qmake builds use a shared libretroshare; CMake links it statically)
for dll in retroshare.dll librnp.dll; do
	if [ -f "$RELEASE/$dll" ]; then cp "$RELEASE/$dll" "$OUT/"; fi
done

# 2. Qt plugins. The Qt DLLs themselves are copied in step 3 like any other
#    DLL. windeployqt is not used: in MSYS2 it often belongs to another Qt
#    version than the one the tool was built with.
echo "== Qt plugins"
MINGW_DIR="${MINGW_PREFIX:-/mingw64}"

if objdump -p "$OUT/$NAME.exe" | grep -qi "DLL Name: Qt6Core.dll"; then QTV=6; else QTV=5; fi

PLUGINS=""
for q in "qmake-qt$QTV" "qmake$QTV" qmake; do
	command -v "$q" >/dev/null || continue
	case "$("$q" -query QT_VERSION 2>/dev/null)" in
		$QTV.*) PLUGINS="$("$q" -query QT_INSTALL_PLUGINS 2>/dev/null)"; break ;;
	esac
done
[ -n "$PLUGINS" ] && PLUGINS="$(cygpath -u "$PLUGINS")"
[ -d "$PLUGINS/platforms" ] || PLUGINS="$MINGW_DIR/share/qt$QTV/plugins"
[ -f "$PLUGINS/platforms/qwindows.dll" ] || fail "Qt $QTV plugins not found (looked in $PLUGINS)."
echo "   Qt $QTV plugins: $PLUGINS"

copy_plugin() {	# copy_plugin <subdir> <file> [required]
	if [ -f "$PLUGINS/$1/$2" ]; then
		mkdir -p "$OUT/$1"
		cp "$PLUGINS/$1/$2" "$OUT/$1/"
	elif [ "$3" = required ]; then
		fail "Qt plugin $1/$2 not found in $PLUGINS"
	fi
}
copy_plugin platforms   qwindows.dll required	# without it the tool does not start
copy_plugin imageformats qsvg.dll required		# icons
copy_plugin imageformats qico.dll
copy_plugin iconengines qsvgicon.dll
copy_plugin styles      qwindowsvistastyle.dll	# native Windows look (Qt 5, Qt 6 < 6.7)
copy_plugin styles      qmodernwindowsstyle.dll	# native Windows look (Qt 6.7+)

# 3. every MSYS2 DLL needed by the exe, the DLLs and the Qt plugins.
#    Uses objdump (part of the compiler tools), following the dependencies
#    of each copied DLL too. System DLLs (KERNEL32, WS2_32...) are not in
#    $MINGW_PREFIX/bin and are skipped.
echo "== MSYS2 DLLs"
MINGW_BIN="${MINGW_PREFIX:-/mingw64}/bin"

dll_imports() {
	objdump -p "$1" 2>/dev/null | sed -n 's/^[[:space:]]*DLL Name: //p' | tr -d '\r'
}

todo="$(cd "$OUT" && find . -name '*.exe' -o -name '*.dll')"
done_list=" "
while [ -n "$todo" ]; do
	next=""
	for f in $todo; do
		for dll in $(dll_imports "$OUT/$f"); do
			lc="$(echo "$dll" | tr 'A-Z' 'a-z')"
			case "$done_list" in *" $lc "*) continue ;; esac
			done_list="$done_list$lc "
			src="$(find "$MINGW_BIN" -maxdepth 1 -iname "$dll" -print -quit)"
			[ -n "$src" ] || continue		# Windows system DLL
			if [ ! -f "$OUT/$(basename "$src")" ]; then
				cp "$src" "$OUT/"
			fi
			next="$next ./$(basename "$src")"
		done
	done
	todo="$next"
done

# 4. short readme
cat > "$OUT/README.txt" <<'TXT'
RetroShare Backup & Restore
===========================

Back up, restore and upgrade RetroShare nodes.

Close RetroShare before using this tool.

- Normal installation: start retroshare-backup.exe, it uses
  %APPDATA%\RetroShare.
- Portable RetroShare: start the tool and click "Choose portable
  folder...", then choose the folder of your portable RetroShare
  (the one with retroshare.exe). Do not copy these files into that
  folder: they could replace RetroShare's own DLLs.

The tool is self-contained: it does not need RetroShare to be installed
and does not use the installed RetroShare files. Keep all files of this
folder together (do not replace its DLLs with other versions).

It works with nodes of any RetroShare 0.6 version: backups contain the
node folder unchanged, plus the PGP key.
Very old RetroShare versions (PGP keyring in Data\pgp instead of
Data\rnp) can be backed up, but a node restored for them only appears
after updating RetroShare.
TXT
sed -i 's/$/\r/' "$OUT/README.txt"

# 5. zip
echo "== Zipping"
rm -f "$ZIP"
cd "$DIST"
if command -v zip >/dev/null; then
	zip -qr "$ZIP" "$NAME"
elif command -v bsdtar >/dev/null; then
	bsdtar -a -cf "$ZIP" "$NAME"
else
	fail "No zip program found. Install one: pacman -S zip   (the files are ready in $OUT)"
fi

echo
echo "Done: $(cygpath -w "$ZIP")"
echo "$(find "$OUT" -type f | wc -l) files"
