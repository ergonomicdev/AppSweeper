# Developer shortcuts. Works with plain `swift` commands too; this just picks a sane toolchain.
# XCTest and the SwiftUI macro plugin only ship with full Xcode, so if the selected developer
# directory isn't an Xcode and /Applications/Xcode.app exists, use it for this invocation.
XCODE_DEV := /Applications/Xcode.app/Contents/Developer
ifeq ($(findstring Xcode,$(shell xcode-select -p 2>/dev/null)),)
ifneq ($(wildcard $(XCODE_DEV)),)
export DEVELOPER_DIR ?= $(XCODE_DEV)
endif
endif

.PHONY: help build run test scan icon project dummy app dmg install clean

help:
	@echo "make build      build with SwiftPM"
	@echo "make run        run the app"
	@echo "make test       run unit tests"
	@echo "make scan APP=/path/to/App.app   read-only scan from the command line"
	@echo "make app        build dist/AppSweeper.app (universal, Release)"
	@echo "make dmg        build dist/AppSweeper-<version>.dmg and .zip"
	@echo "make install    build and copy AppSweeper.app to /Applications"
	@echo "make icon       regenerate the app icon"
	@echo "make project    regenerate AppSweeper.xcodeproj (needs xcodegen)"
	@echo "make dummy      create SweepTestDummy.app + leftovers (see README)"
	@echo "make clean      remove build products"

build:
	swift build

run:
	swift run AppSweeper

test:
	swift test

scan:
	@test -n "$(APP)" || (echo "usage: make scan APP=/path/to/App.app" && exit 2)
	swift run appsweeper-scan "$(APP)"

icon:
	swift Tools/GenerateIcon.swift

project:
	xcodegen generate

dummy:
	Tools/make-test-app.sh create

app dmg:
	Tools/package-app.sh

install: app
	rm -rf /Applications/AppSweeper.app
	cp -R dist/AppSweeper.app /Applications/
	@echo "Installed /Applications/AppSweeper.app"

clean:
	rm -rf .build dist
