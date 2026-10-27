PROJECT = Cabral.xcodeproj
XCB = xcodebuild -project $(PROJECT) -scheme Cabral -derivedDataPath build -quiet
# Pin the host arch: "My Mac" is listed once per arch on Apple silicon.
DEST = -destination 'platform=macOS,arch=$(shell uname -m)'

.PHONY: project build run install test lint format clean bump release

project:
	@command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen"; exit 1; }
	xcodegen generate --quiet

build: project
	$(XCB) $(DEST) -configuration Debug build

run: build
	open build/Build/Products/Debug/Cabral.app

# Local ad-hoc Release build; replaces /Applications/Cabral.app (including a notarized one).
install: project
	$(XCB) -configuration Release build
	rm -rf /Applications/Cabral.app
	cp -R build/Build/Products/Release/Cabral.app /Applications/

test: project
	$(XCB) $(DEST) test

lint:
	xcrun swift-format lint --strict --recursive --parallel Cabral CabralTests

format:
	xcrun swift-format format --in-place --recursive --parallel Cabral CabralTests

clean:
	rm -rf build Cabral.xcodeproj

# make bump V=0.2.0
bump:
	@test -n "$(V)" || { echo "usage: make bump V=x.y.z"; exit 1; }
	./scripts/bump-version.sh $(V)

# Maintainers only: Developer ID signing + notarization (see docs/RELEASING.md)
release:
	./scripts/release.sh
