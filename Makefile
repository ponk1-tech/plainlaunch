SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT := PlainLaunch.xcodeproj
SCHEME := PlainLaunch
BUNDLE_ID := com.ponk1tech.plainlaunch
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
export PLAINLAUNCH_BUILD_NUMBER := $(BUILD_NUMBER)

.PHONY: help generate build test archive validate upload testflight metadata submit \
        screenshots icon clean device-build device-install

help:
	@echo "PlainLaunch release commands (build number: $(BUILD_NUMBER))"
	@echo ""
	@echo "  make generate       Regenerate the Xcode project with XcodeGen"
	@echo "  make build          Debug build for the Simulator"
	@echo "  make test           Run the unit tests"
	@echo "  make device-build   Debug build + install on the connected device (see scripts/device.sh)"
	@echo "  make icon           Regenerate the App Icon (tools/AppIcon/generate_icon.py)"
	@echo "  make screenshots    Capture App Store screenshots (ja + en)"
	@echo "  make archive        Release archive + .ipa export (scripts/archive.sh)"
	@echo "  make validate       Validate the exported .ipa with the App Store Connect API"
	@echo "  make upload         Upload the exported .ipa to App Store Connect"
	@echo "  make testflight     Poll build processing, then enable it for internal TestFlight"
	@echo "  make metadata       Push App Store metadata (name/description/keywords/etc.) via the API"
	@echo "  make submit         Create and submit an App Store review submission via the API"

generate:
	xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination 'generic/platform=iOS Simulator' -configuration Debug build

test: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 16e' test

device-build: generate
	./scripts/device.sh build

device-install: generate
	./scripts/device.sh install

icon:
	python3 tools/AppIcon/generate_icon.py

screenshots:
	./scripts/screenshots.sh

archive: generate
	./scripts/archive.sh

validate:
	./scripts/upload.sh validate

upload:
	./scripts/upload.sh upload

testflight:
	node scripts/asc_testflight.js

metadata:
	node scripts/asc_metadata.js

submit:
	node scripts/asc_submit.js

clean:
	rm -rf build $(PROJECT)
