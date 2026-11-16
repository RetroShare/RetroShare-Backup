# RetroShare Backup & Restore - qmake project
#
# Standalone tool to back up, restore and upgrade RetroShare nodes while
# RetroShare itself is closed. Builds against an existing RetroShare checkout
# (libretroshare must be built first).
#
#   qmake                                   finds RetroShare by itself: the parent
#                                           folder (cloned inside RetroShare) or
#                                           ../RetroShare (cloned next to it)
#   qmake RS_DIR=<RetroShare source>        any other RetroShare checkout
#   qmake RS_DIR=<src> RS_BUILD_DIR=<dir>   if RetroShare was built out of source
#
# RS_DIR and RS_BUILD_DIR can also be set as environment variables.
#
# SPDX-FileCopyrightText: Retroshare Team <contact@retroshare.cc>
# SPDX-License-Identifier: AGPL-3.0-or-later

########################### where is RetroShare? ##############################

isEmpty(RS_DIR): RS_DIR = $$(RS_DIR)
# cloned inside the RetroShare folder (RetroShare/RetroShare-Backup) ...
isEmpty(RS_DIR):exists($$PWD/../retroshare.pri): RS_DIR = $$PWD/..
# ... or next to it (RetroShare-Backup and RetroShare in the same folder)
isEmpty(RS_DIR): RS_DIR = $$PWD/../RetroShare
RS_DIR = $$clean_path($$RS_DIR)

!exists($$RS_DIR/retroshare.pri) {
	error("RetroShare source not found in $$RS_DIR - run: qmake RS_DIR=<path to your RetroShare checkout>")
}

isEmpty(RS_BUILD_DIR): RS_BUILD_DIR = $$(RS_BUILD_DIR)
isEmpty(RS_BUILD_DIR): RS_BUILD_DIR = $$RS_DIR
RS_BUILD_DIR = $$clean_path($$RS_BUILD_DIR)

message("RetroShare source: $$RS_DIR")
message("RetroShare build:  $$RS_BUILD_DIR")

!include($$RS_DIR/retroshare.pri): error("Could not include $$RS_DIR/retroshare.pri")

TEMPLATE = app
TARGET = retroshare-backup

QT += core gui widgets svg

!include($$RS_DIR/libretroshare/src/use_libretroshare.pri): error("Could not include use_libretroshare.pri")

# use_libretroshare.pri is meant for projects inside the RetroShare tree and
# looks for the built libraries two levels above this project. Point those
# paths to the real RetroShare build directory.
RS_ASSUMED_BUILD = $$clean_path($$OUT_PWD/../..)
!equals(RS_ASSUMED_BUILD, $$RS_BUILD_DIR) {
	for(sub, $$list(libretroshare supportlibs libbitdht openpgpsdk)) {
		LIBS           = $$replace(LIBS,           $$RS_ASSUMED_BUILD/$$sub, $$RS_BUILD_DIR/$$sub)
		QMAKE_LIBDIR   = $$replace(QMAKE_LIBDIR,   $$RS_ASSUMED_BUILD/$$sub, $$RS_BUILD_DIR/$$sub)
		INCLUDEPATH    = $$replace(INCLUDEPATH,    $$RS_ASSUMED_BUILD/$$sub, $$RS_BUILD_DIR/$$sub)
		DEPENDPATH     = $$replace(DEPENDPATH,     $$RS_ASSUMED_BUILD/$$sub, $$RS_BUILD_DIR/$$sub)
		PRE_TARGETDEPS = $$replace(PRE_TARGETDEPS, $$RS_ASSUMED_BUILD/$$sub, $$RS_BUILD_DIR/$$sub)
	}
}

################################## sources #####################################

INCLUDEPATH += $$PWD/src
DEPENDPATH  += $$PWD/src

HEADERS += \
    src/MainWindow.h \
    src/NodeInfo.h \
    src/ProfileArchive.h \
    src/ProfileUpgrader.h \
    src/ProfileUpgradeDialog.h

SOURCES += \
    src/main.cpp \
    src/MainWindow.cpp \
    src/NodeInfo.cpp \
    src/ProfileArchive.cpp \
    src/ProfileUpgrader.cpp \
    src/ProfileUpgradeDialog.cpp

FORMS += \
    src/MainWindow.ui \
    src/ProfileUpgradeDialog.ui

RESOURCES += resources.qrc

# NodeInfo reads the node certificates directly
LIBS *= -lcrypto

MOC_DIR = temp/moc
UI_DIR  = temp/ui
RCC_DIR = temp/qrc
OBJECTS_DIR = temp/obj

################################### Linux #####################################

unix:!macx {
	isEmpty(PREFIX): PREFIX = /usr
	target.path = $$PREFIX/bin
	INSTALLS += target
}

################################### macOS #####################################

macx {
	LIBS += -lz
	for(lib, LIB_DIR):exists($$lib/libminiupnpc.a){ LIBS += $$lib/libminiupnpc.a}
	LIBS += -framework CoreFoundation -framework Security -framework Carbon

	LIBRNP_BUILD_PATH = $$clean_path($$RS_BUILD_DIR/supportlibs/librnp/Build)
	LIBS += -L$$clean_path($${LIBRNP_BUILD_PATH}/src/lib) -lrnp
	LIBS += -L$$clean_path($${LIBRNP_BUILD_PATH}/src/libsexpp) -lsexpp
	LIBS += -lbz2 -lz -ljson-c -lbotan-2

	for(lib, LIB_DIR):LIBS += -L"$$lib"
	for(bin, BIN_DIR):LIBS += -L"$$bin"
	DEPENDPATH += . $$INC_DIR
	INCLUDEPATH += . $$INC_DIR
}

################################## Windows ####################################

win32-g++|win32-clang-g++ {
	CONFIG(debug, debug|release) {
		CONFIG += console
	} else {
		QMAKE_LFLAGS += -Wl,-dynamicbase -Wl,-nxcompat
	}

	# too many exported symbols otherwise (ld: export ordinal too large)
	QMAKE_LFLAGS += -Wl,--exclude-libs,ALL

	dLib = ws2_32 gdi32 uuid ole32 iphlpapi crypt32 winmm
	LIBS *= $$linkDynamicLibs(dLib)

	RC_ICONS = images/retroshare-backup.ico
}
