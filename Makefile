.PHONY: build
build: generate runtime
	@docker build -t cdktf-gcp .
	@echo Docker container cdktf-gcp built

.PHONY: runtime
runtime:
	@cd runtime && go build -o runtime ./cmd/main.go

.PHONY: install
install:
	@uv sync --dev

.PHONY: generate
generate: install clean
	@npx -y cdktf-cli@0.20.8 get
	@touch imports/__init__.py

clean:
	@rm -rf imports

run:
	@docker run -it --rm -v $(PWD)/cdktf:/cdktf mapfre