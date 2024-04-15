.PHONY: build
build:
	@docker build -t cdktf-gcp .

install:
	@pipenv install --dev

generate:
	@cdktf get

run:
	@docker run -it --rm -v $(PWD)/cdktf:/cdktf cdktf-gcp