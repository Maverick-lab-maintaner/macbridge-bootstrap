.PHONY: test lint build clean

# Run test harness
test:
	bash test/run-tests.sh

# ShellCheck lint (requires shellcheck: brew install shellcheck)
lint:
	find . -name '*.sh' -not -path './.git/*' -not -path './.cache/*' -print0 | xargs -0 shellcheck -x

# Syntax-only check (no ShellCheck dependency)
check:
	find . -name '*.sh' -not -path './.git/*' -not -path './.cache/*' -print0 | xargs -0 -I {} bash -n {}

# Build Go CLI
build:
	go build -o macbridge ./cmd/macbridge/

# Build Go CLI for Linux (CI)
build-linux:
	GOOS=linux GOARCH=amd64 go build -o macbridge-linux ./cmd/macbridge/

# Clean build artifacts
clean:
	rm -f macbridge macbridge.exe macbridge-linux
	rm -rf .cache/
