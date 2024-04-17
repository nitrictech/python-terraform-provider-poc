.PHONY: build
build: generate
	@docker build -t cdktf-gcp .

install:
	@pipenv install --dev

generate: install clean
	@cdktf get

clean:
	@rm -rf imports

run:
	@docker run -it --rm -v $(PWD)/cdktf:/cdktf cdktf-gcp