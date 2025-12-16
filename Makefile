TITLE := Template

.PHONY: pre-build release dev clean

pre-build:
	@echo "Getting ready for build..."
	@musl-go build -buildmode=c-archive -ldflags="-s -w" -trimpath -o ./Libs/goutil/libgoutil.a ./Libs/goutil/
	@mkdir -p ./Sources/GoUtil
	@mv ./Libs/goutil/libgoutil.h ./Sources/GoUtil/libgoutil.h
	@echo "Pre-built done!\n"

dev:
	@make pre-build
	@swift build --swift-sdk x86_64-swift-linux-musl
	@echo "Successfully built \`./.build/debug/$(TITLE)\` for debug."
	@echo "Executing...\n" && ./.build/debug/$(TITLE)

release:
	@make pre-build
	@mkdir -p ./bin
	@swift build --swift-sdk x86_64-swift-linux-musl -c release \
		-Xswiftc -O \
		-Xswiftc -whole-module-optimization \
		-Xswiftc -cross-module-optimization \
		-Xlinker -s
	@cp ./.build/release/$(TITLE) ./bin/
	@echo "Successfully built \`./bin/$(TITLE)\` for release."

clean:
	@rm -rf ./bin/*
	swift package clean
	swift package reset
