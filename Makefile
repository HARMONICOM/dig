.PHONY: setup build up down exec zig logs

CP := cmd /c copy
USER_ID := 1
GROUP_ID := 1

ifneq ($(OS),Windows_NT)
  CP := cp
  USER_ID := $(shell id -u)
  GROUP_ID := $(shell id -g)
endif

# Adjust file permissions
ap:
	docker compose run --rm app chown -f -R $(USER_ID):$(GROUP_ID) . | true

build:
	docker compose build

build-nocache:
	docker compose build --no-cache

up:
	docker compose up -d

down:
	docker compose down

run:
	docker compose run --rm --service-ports app $(filter-out $@,$(MAKECMDGOALS))
	@exit 3

zig:
	docker compose run --rm --service-ports app zig $(filter-out $@,$(MAKECMDGOALS))
	@exit 3

logs:
	docker compose logs -f $(filter-out $@,$(MAKECMDGOALS))
	@exit 3
