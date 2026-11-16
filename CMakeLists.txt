# RetroShare Backup & Restore - CMake build
#
# Like retroshare-service, libretroshare is compiled from source together with
# the tool (static by default), so no separate libretroshare build is needed.
# libretroshare source is looked for, in this order:
#   1. -DLIBRETROSHARE_DIR=<libretroshare source>
#   2. <RS_DIR>/libretroshare        (RS_DIR: the parent folder when cloned
#                                     inside RetroShare, else ../RetroShare)
#   3. ../libretroshare              (a separate libretroshare checkout)
#   4. downloaded from github.com/RetroShare/libretroshare
#
# SPDX-FileCopyrightText: Retroshare Team <contact@retroshare.cc>
# SPDX-License-Identifier: AGPL-3.0-or-later

cmake_minimum_required(VERSION 3.18.0)
project(retroshare-backup LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

# Default: the parent folder if this was cloned inside RetroShare
# (RetroShare/RetroShare-Backup), otherwise ../RetroShare (cloned next to it).
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../libretroshare/CMakeLists.txt"
        AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../retroshare.pri")
	set(RS_DIR_DEFAULT "${CMAKE_CURRENT_SOURCE_DIR}/..")
else()
	set(RS_DIR_DEFAULT "${CMAKE_CURRENT_SOURCE_DIR}/../RetroShare")
endif()
set(RS_DIR "${RS_DIR_DEFAULT}"
    CACHE PATH "RetroShare source checkout; its libretroshare is used")
set(LIBRETROSHARE_DIR ""
    CACHE PATH "libretroshare source directory (overrides RS_DIR/libretroshare)")
set(RS_BIN_INSTALL_DIR "${CMAKE_INSTALL_PREFIX}/bin"
    CACHE PATH "Where to install retroshare-backup")

################################## Qt ##########################################

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Widgets)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Widgets Svg)
message(STATUS "Using Qt ${QT_VERSION}")

############################## libretroshare ###################################

# The tool needs no JSON API (libretroshare default is OFF anyway)
set(RS_JSON_API OFF CACHE BOOL "Use restbed to expose libretroshare as JSON API via HTTP")

if(NOT TARGET retroshare)
	get_filename_component(RS_DIR "${RS_DIR}" ABSOLUTE)
	get_filename_component(RS_SIBLING_LIB "${CMAKE_CURRENT_SOURCE_DIR}/../libretroshare" ABSOLUTE)

	set(LIBRETROSHARE_SRC "")
	if(LIBRETROSHARE_DIR AND EXISTS "${LIBRETROSHARE_DIR}/CMakeLists.txt")
		set(LIBRETROSHARE_SRC "${LIBRETROSHARE_DIR}")
	elseif(EXISTS "${RS_DIR}/libretroshare/CMakeLists.txt")
		set(LIBRETROSHARE_SRC "${RS_DIR}/libretroshare")
	elseif(EXISTS "${RS_SIBLING_LIB}/CMakeLists.txt")
		set(LIBRETROSHARE_SRC "${RS_SIBLING_LIB}")
	endif()

	if(LIBRETROSHARE_SRC)
		message(STATUS "libretroshare source: ${LIBRETROSHARE_SRC}")
		add_subdirectory("${LIBRETROSHARE_SRC}" "${CMAKE_BINARY_DIR}/libretroshare")
	else()
		message(STATUS "libretroshare source not found locally, downloading it")
		include(FetchContent)
		set(FETCHCONTENT_QUIET OFF)
		FetchContent_Declare(
			libretroshare
			GIT_REPOSITORY "https://github.com/RetroShare/libretroshare.git"
			GIT_TAG "origin/master"
			GIT_SHALLOW TRUE
			GIT_PROGRESS TRUE
			TIMEOUT 10 )
		FetchContent_MakeAvailable(libretroshare)
	endif()
endif()

# NodeInfo.cpp and ProfileUpgrader.cpp use OpenSSL headers directly
find_package(OpenSSL REQUIRED)

################################ the tool ######################################

set(RS_BACKUP_SOURCES
	src/main.cpp
	src/MainWindow.cpp
	src/MainWindow.h
	src/MainWindow.ui
	src/NodeInfo.cpp
	src/NodeInfo.h
	src/ProfileArchive.cpp
	src/ProfileArchive.h
	src/ProfileUpgrader.cpp
	src/ProfileUpgrader.h
	src/ProfileUpgradeDialog.cpp
	src/ProfileUpgradeDialog.h
	src/ProfileUpgradeDialog.ui
	resources.qrc )

if(WIN32)
	list(APPEND RS_BACKUP_SOURCES images/retroshare-backup.rc)
endif()

add_executable(${PROJECT_NAME} WIN32 MACOSX_BUNDLE ${RS_BACKUP_SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE src)

target_link_libraries(
	${PROJECT_NAME} PRIVATE
	retroshare
	Qt${QT_VERSION_MAJOR}::Widgets
	Qt${QT_VERSION_MAJOR}::Svg
	OpenSSL::Crypto )

if(WIN32)
	target_link_libraries(${PROJECT_NAME} PRIVATE ws2_32 winmm iphlpapi mswsock)
endif()

install(TARGETS ${PROJECT_NAME}
	RUNTIME DESTINATION "${RS_BIN_INSTALL_DIR}"
	BUNDLE DESTINATION "${RS_BIN_INSTALL_DIR}" )
