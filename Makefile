TEMPLATE_NAME ?= janus

run-demo:
	docker-compose up
	@echo "open brower at http://localhost:8000 port"
