# RetroShare Backup & Restore

A small standalone tool to **back up**, **restore** and **upgrade** [RetroShare](https://github.com/RetroShare/RetroShare) nodes.
Use it while RetroShare is closed.

## Features

### Back up
- Saves a node into one `.rsprofile` file: the PGP key pair, SSL keys and certificate,
  all settings (friends, network, history…), the GXS databases (identities, forums,
  channels, boards, circles), GUI settings, the Tor/I2P hidden service keys, file lists
  and stickers.
- Nothing is decrypted: the backup is as safe as the node folder itself, and still
  needs your PGP password to be used.
- `Downloads`, `Partials` and Tor runtime data are left out.
- A running node is refused, so databases are never copied half-written.
- The file is a plain tar archive (can be opened with 7-Zip or `tar`).

### Restore
- Shows what is in the backup (profile, node, ID, date) before restoring.
- Adds the PGP key only if it is not already on the computer.
- Never overwrites an existing node; checks the archive and undoes everything on error.
- Works on a fresh installation and for portable RetroShare.

### Upgrade to new keys
For old nodes whose certificate is too weak for current OpenSSL versions:
creates a new node of the same profile with new, strong SSL keys and moves everything
to it (friends, settings, identities, forums, channels, messages, hidden service).
The PGP key stays the same, the node gets a new node ID. The old node is not modified.
A backup is made first by default.

Based on hunbernd's
[retroshare-profileupgradetool](https://github.com/hunbernd/RetroShare/tree/accountupgradetool).

### Node overview
- All nodes of the data folder, with node type (standard / hidden), key strength
  (old keys are flagged), and when the node was last used.
- PGP keyring type of the data folder (RNP, or old OpenPGP-SDK).
- Portable RetroShare: detected automatically, or choose the portable folder.

## Compatibility
- Works with nodes of any RetroShare 0.6 version: backups contain the node folder
  unchanged, plus the PGP key. Backups can be moved between Windows, Linux and macOS.
- Very old RetroShare versions (PGP keyring in `Data\pgp` instead of `Data\rnp`) can be
  backed up, but a node restored for them only appears after updating RetroShare.

## Usage

```
retroshare-backup                  standard data folder (%APPDATA%\RetroShare, ~/.retroshare)
retroshare-backup -c <folder>      another data folder, or a portable RetroShare folder
```

## Building

The tool uses **libretroshare** from a RetroShare source checkout. Clone this
repository **inside your RetroShare folder** (recommended), or next to it.
The build finds RetroShare by itself in both cases.

Inside RetroShare:

```
RetroShare/                  RetroShare source (git clone --recursive)
├── libretroshare/
├── retroshare-gui/
├── ...
└── RetroShare-Backup/       this repository
```

```sh
git clone --recursive https://github.com/RetroShare/RetroShare.git
cd RetroShare
git clone https://github.com/defnax/RetroShare-Backup.git
echo RetroShare-Backup/ >> .git/info/exclude   # optional: hide it from RetroShare's git status
```

Or next to it: `RetroShare/` and `RetroShare-Backup/` in the same folder.

Anywhere else: tell the build where RetroShare is (`RS_DIR`, see below).

### CMake (recommended)

CMake compiles libretroshare together with the tool, like `retroshare-service`
does: RetroShare does not need to be built first.

```sh
cd RetroShare-Backup
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j4
```

Options:

| Option | Default | |
|---|---|---|
| `-DRS_DIR=<path>` | parent folder, or `../RetroShare` | RetroShare checkout whose `libretroshare` is used |
| `-DLIBRETROSHARE_DIR=<path>` | | use a separate libretroshare checkout instead |

If no libretroshare source is found (neither `RS_DIR/libretroshare` nor
`../libretroshare`), it is downloaded from GitHub.

On Windows, run it in the MSYS2 MINGW64 shell (add `-G "MSYS Makefiles"` if
CMake does not pick a generator by itself).

### qmake

qmake links against an **already built** RetroShare (built with qmake):

```sh
cd RetroShare-Backup
qmake CONFIG+=release                 # finds RetroShare (parent folder or ../RetroShare)
qmake RS_DIR=/path/to/RetroShare      # RetroShare somewhere else
qmake RS_DIR=<src> RS_BUILD_DIR=<dir> # RetroShare built out of source
make                                  # mingw32-make on Windows (MSYS2)
```

Use the same qmake options (`CONFIG+=...`) as for your RetroShare build.

### Windows bundle
After a release build (CMake or qmake), run `make-zip.bat` (double-click). It
creates `dist\retroshare-backup-<date>.zip` with the exe, Qt (DLLs and plugins),
all needed MSYS2 DLLs, and `retroshare.dll`/`librnp.dll` for qmake builds.
MSYS2 is looked for in `C:\msys64`, or set `MSYS2_ROOT`.

## License
AGPL-3.0-or-later, like RetroShare. See [LICENSE](LICENSE).
