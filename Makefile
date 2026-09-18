# 好查经 (ChaJing) — macOS Bible lookup app.
#
#   make data      regenerate Sources/ChaJing/Resources/cus.json (needs python3 + opencc)
#   make build     swift build -c release
#   make app       assemble dist/好查经.app (ad-hoc signed)
#   make run       build the .app and open it
#   make test      swift test
#   make ui-shots  render offscreen UI screenshots into docs/ui/shots/ (never shows a window)
#   make install   copy dist/好查经.app to /Applications
#   make icon      rebuild packaging/AppIcon.icns from packaging/icon-source.png
#   make vm-run    build on the host, run the app inside the Tart VM (scripts/vm.sh)

APP      := ChaJing
BUNDLE   := 好查经
CONFIG   := release
BUILD    := .build/$(CONFIG)
DIST     := dist/$(BUNDLE).app
CONTENTS := $(DIST)/Contents

.PHONY: data build app run test ui-shots install clean vm-setup vm-run vm-stop

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
	cp packaging/AppIcon.icns "$(CONTENTS)/Resources/AppIcon.icns"
	printf 'APPL????' > "$(CONTENTS)/PkgInfo"
	codesign --force --deep --sign - "$(DIST)"
	@echo "built $(DIST)"

run: app
	open "$(DIST)"

test:
	swift test

ui-shots:
	CHAJING_UI_SHOTS=1 swift test --filter UISnapshotTests

install: app
	rm -rf "/Applications/$(BUNDLE).app"
	cp -R "$(DIST)" /Applications/
	@echo "installed to /Applications/$(BUNDLE).app"

vm-setup:
	scripts/vm.sh setup

vm-run: app
	scripts/vm.sh start
	scripts/vm.sh run

vm-stop:
	scripts/vm.sh stop

# Flat artwork -> macOS-shaped tile -> all iconset sizes -> .icns (see scripts/make_icns.sh)
icon:
	scripts/make_icns.sh packaging/icon-source.png packaging/AppIcon.icns

clean:
	rm -rf .build dist
