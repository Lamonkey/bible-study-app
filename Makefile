# ChaJing (查经) — macOS menu-bar Bible lookup.
#
#   make data      regenerate Sources/ChaJing/Resources/cus.json (needs python3 + opencc)
#   make build     swift build -c release
#   make app       assemble dist/ChaJing.app (ad-hoc signed)
#   make run       build the .app and open it
#   make test      swift test
#   make install   copy dist/ChaJing.app to /Applications

APP      := ChaJing
CONFIG   := release
BUILD    := .build/$(CONFIG)
DIST     := dist/$(APP).app
CONTENTS := $(DIST)/Contents

.PHONY: data build app run test install clean

data:
	python3 scripts/build_data.py

build:
	swift build -c $(CONFIG)

app: build
	rm -rf "$(DIST)"
	mkdir -p "$(CONTENTS)/MacOS" "$(CONTENTS)/Resources"
	cp "$(BUILD)/$(APP)" "$(CONTENTS)/MacOS/$(APP)"
	cp -R "$(BUILD)/$(APP)_$(APP).bundle" "$(CONTENTS)/Resources/"
	cp packaging/Info.plist "$(CONTENTS)/Info.plist"
	printf 'APPL????' > "$(CONTENTS)/PkgInfo"
	codesign --force --deep --sign - "$(DIST)"
	@echo "built $(DIST)"

run: app
	open "$(DIST)"

test:
	swift test

install: app
	rm -rf "/Applications/$(APP).app"
	cp -R "$(DIST)" /Applications/
	@echo "installed to /Applications/$(APP).app"

clean:
	rm -rf .build dist
