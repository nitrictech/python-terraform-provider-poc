.PHONY: build
build: generate
	@docker build -t cdktf-gcp .
	@echo Docker container cdktf-gcp built

.PHONY: install
install:
	@export PIPENV_VERBOSITY=-1
	@pipenv install --dev

.PHONY: generate
generate: install clean
	@cdktf get
	@touch imports/__init__.py

clean:
	@rm -rf imports

run:
	@docker run -it --rm -v $(PWD)/cdktf:/cdktf cdktf-gcp