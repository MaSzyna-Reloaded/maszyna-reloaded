.PHONY: install runserver

BASEURL := /game
# Without Ruby on the host the site is built in the official Ruby image. The gems live in a named volume, so they are installed once, and the site is
# built inside the container rather than into docs/, which would otherwise fill up with files owned
# by root.
DOCKER_RUBY_IMAGE := ruby:3.3
DOCKER_GEMS_VOLUME := maszyna-game-docs-gems
DOCKER_RUN := docker run --rm -it -v "$(abspath $(CURDIR)/..):/srv" -v $(DOCKER_GEMS_VOLUME):/usr/local/bundle \
	-w /srv/docs -p 4000:4000 -p 35729:35729 $(DOCKER_RUBY_IMAGE)

ifneq ($(shell command -v bundle),)

install:
	bundle install

runserver: install
	bundle exec jekyll serve --livereload --baseurl "$(BASEURL)"

else

install:
	$(DOCKER_RUN) bundle install

runserver:
	$(DOCKER_RUN) sh -c 'bundle install && bundle exec jekyll serve --host 0.0.0.0 --livereload \
		--baseurl "$(BASEURL)" --destination /tmp/site'

endif
