.PHONY: image Gemfile.lock

image:
	docker build \
	  --tag codeclimate/test-coverage-report .

Gemfile.lock:
	docker run --rm \
		--user $(whoami):$(whoami) \
		--volume $(PWD):/usr/src/app \
		codeclimate/test-coverage-report \
		bundle install
