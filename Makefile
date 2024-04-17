.PHONY: build
build: generate
	@docker build -t cdktf-gcp .

.PHONY: install
install:
	@pipenv install --dev

.PHONY: generate
generate: install clean
	@cdktf get

clean:
	@rm -rf imports

run:
	@docker run -it --rm -v $(PWD)/cdktf:/cdktf cdktf-gcp