.DEFAULT_GOAL :=
.PHONY: default
default: shell

IMAGE_NAME := llmshell
MODEL_FILE := models/qwen2.5-0.5b-instruct-q4_k_m.gguf
MODEL_URL := https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf
MODEL_SHA256 := 74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db

.PHONY: models
models:
	mkdir -p models
	@if [ -f "$(MODEL_FILE)" ] && echo "$(MODEL_SHA256)  $(MODEL_FILE)" | sha256sum -c - >/dev/null 2>&1; then \
		echo "$(MODEL_FILE): OK"; \
	else \
		wget -O "$(MODEL_FILE)" "$(MODEL_URL)"; \
		echo "$(MODEL_SHA256)  $(MODEL_FILE)" | sha256sum -c -; \
	fi

out:
	mkdir -p out

out/shell.digest: Containerfile index.html | out
	docker build --progress=plain --target shell -f Containerfile -t $(IMAGE_NAME) .
	@touch $@

.PHONY: shell
shell: out/shell.digest
	docker run -it $(IMAGE_NAME)

.PHONY: reproduce
vm: out/shell.digest
	docker run -it $(IMAGE_NAME) sh -c "\
		llama-cpp --version
		"

.PHONY: clean
clean:
	rm -rf out
	@docker rm -f $$(docker ps -aq --filter "ancestor=$(IMAGE_NAME)") 2>/dev/null || true

.PHONY: stop
stop:
	@docker rm -f $$(docker ps -aq --filter "ancestor=$(IMAGE_NAME)") 2>/dev/null || true

.PHONY: dev
dev: stop out/shell.digest
	docker run -d --rm -p 8083:8083 $(IMAGE_NAME)
	@echo "llmshell running at http://localhost:8083"

.PHONY: rebuild
rebuild: stop models
	docker build --no-cache --progress=plain --target shell -f Containerfile -t $(IMAGE_NAME) .
	docker run -d --rm -p 8083:8083 -v ./models:/workdir/models $(IMAGE_NAME) \
		/usr/bin/llama-server --host 0.0.0.0 --port 8083 -m /workdir/$(MODEL_FILE) --path /workdir/public --ctx-size 2048 -t 8
	@echo "llmshell running at http://localhost:8083"

.PHONY: update
update:
	python3 scripts/update.py
