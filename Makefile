.DEFAULT_GOAL :=
.PHONY: default
default: shell

IMAGE_NAME := llmshell

.PHONY: models
models: \
	models/phi-3.1-mini.gguf

out:
	mkdir -p out

models/phi-3.1-mini.gguf:
	mkdir -p models
	wget -nc -O $@ \
		https://huggingface.co/bartowski/Phi-3.1-mini-4k-instruct-GGUF/resolve/main/Phi-3.1-mini-4k-instruct-Q4_K_M.gguf || :
	touch $@

out/shell.digest: Containerfile index.html | out
	docker build --progress=plain --target shell -f Containerfile -t $(IMAGE_NAME) .
	@touch $@

.PHONY: shell
shell: out/shell.digest
	docker run -it $(IMAGE_NAME)

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
		/usr/bin/llama-server --host 0.0.0.0 --port 8083 -m /workdir/models/phi-3.1-mini.gguf --path /workdir/public --ctx-size 4096 -t 12
	@echo "llmshell running at http://localhost:8083"
