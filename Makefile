.PHONY: help test lint build clean

help:
	@printf '%s\n' 'Available targets:' '  help   Show this message' '  test   Report that tests are not configured yet' '  lint   Report that linting is not configured yet' '  build  Report that no application build is configured yet' '  clean  Remove no files (nothing is generated yet)'

test:
	@echo 'Tests are not configured yet (repository skeleton phase).'

lint:
	@echo 'Linting is not configured yet (repository skeleton phase).'

build:
	@echo 'No application build is configured yet (repository skeleton phase).'

clean:
	@echo 'Nothing to clean (repository skeleton phase).'
