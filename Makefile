TITLE := Template

.PHONY: pre-build release dev clean

dev:
	@swift build --swift-sdk x86_64-swift-linux-musl
	@echo "Successfully built \`./.build/debug/$(TITLE)\` for debug."
	@echo "Executing...\n" && ./.build/debug/$(TITLE)

release:
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
