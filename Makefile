.PHONY: build
build: generate
	@docker build -t cdktf-gcp .

install:
	@pipenv install --dev

generate: install
	@cdktf get

run:
	@docker run -it --rm -v $(PWD)/cdktf:/cdktf cdktf-gcp