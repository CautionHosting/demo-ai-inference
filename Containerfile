FROM stagex/core-busybox@sha256:01b31cc07543733fbf6889e596427af943aba2780bc2f514a3d30bb290da7e2a AS core-busybox
FROM stagex/core-musl@sha256:23d0614f60449015add2369959c89a6ea08e208302773b9a0811ce1195afc3a4 AS core-musl
FROM stagex/core-gcc@sha256:02896413375c15cbff666fbab7c534caefc8936d53e167a6ea457a05c27e8096 AS core-gcc
FROM stagex/core-git@sha256:6b3e0055f6aeaa8465f207a871db2c63a939cd7406113e9d769ff3b37239f3d0 AS git
FROM stagex/core-ca-certificates@sha256:d135f1189e9b232eb7316626bf7858534c5540b2fc53dced80a4c9a95f26493e AS ca-certificates
FROM stagex/core-curl@sha256:bc8bab43d96a9167fbb85022ea773644a45ef335e7a9b747f203078973fa988e AS curl
FROM stagex/pallet-nodejs@sha256:1f705b58321b17e87ea68c04431ad83be6e6b64253d0443be4c61501902d57c3 AS pallet-nodejs
FROM stagex/pallet-gcc-cmake-busybox@sha256:41cd386c19d8a5b34bec3d929dfeee5c1967663e27e7fa81dde6d14b419ee95e AS pallet-gcc-cmake-busybox
FROM stagex/user-llama-cpp@sha256:8300184b1f65fa7014ee6c06cab343ee55022b228f43f7960c2355fb9cc4a380 AS llama

FROM pallet-nodejs AS js-builder
COPY --from=git . /
COPY --from=ca-certificates . /
COPY --from=curl . /
ARG STEVE_COMMIT=1dee1a0d55d1106fd8a237c09733406489cc8d12
ARG ATTESTATION_WIDGET_COMMIT=47b24ef7e3fd8d51982678b78cd0c62afb31e4f3
WORKDIR /build/steve
RUN git init . && \
    git remote add origin https://git.distrust.co/public/steve.git && \
    git fetch --depth 1 origin "${STEVE_COMMIT}" && \
    git checkout --detach FETCH_HEAD && \
    test "$(git rev-parse HEAD)" = "${STEVE_COMMIT}"
WORKDIR /build/steve/steve-js-sdk
RUN npm install && npm run build
WORKDIR /build/attestation-widget
RUN git init . && \
    git remote add origin https://git.distrust.co/public/attestation-widget.git && \
    git fetch --depth 1 origin "${ATTESTATION_WIDGET_COMMIT}" && \
    git checkout --detach FETCH_HEAD && \
    test "$(git rev-parse HEAD)" = "${ATTESTATION_WIDGET_COMMIT}"

FROM pallet-gcc-cmake-busybox AS download
COPY --from=ca-certificates . /
COPY --from=curl . /
ARG MODEL_SHA256=74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db
RUN mkdir -p /models && \
    curl -fSL --retry 5 --retry-delay 10 -o /models/model.gguf \
    https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf && \
        echo "${MODEL_SHA256}  /models/model.gguf" | sha256sum -c -


FROM pallet-gcc-cmake-busybox AS shell
ENTRYPOINT []
COPY --from=core-busybox . /
COPY --from=core-musl . /
COPY --from=llama . /
WORKDIR /workdir

COPY --from=download /models/model.gguf /workdir/models/model.gguf
COPY index.html /workdir/public/index.html
COPY --from=js-builder /build/steve/steve-js-sdk/dist/enclave-sw.js /workdir/public/enclave-sw.js
COPY --from=js-builder /build/steve/steve-js-sdk/dist/register.js /workdir/public/register.js
COPY --from=js-builder /build/attestation-widget/dist/index.js /workdir/public/attestation-widget.js

EXPOSE 8083

CMD ["/usr/bin/llama-server", "--host", "0.0.0.0", "--port", "8083", "-m", "/workdir/models/model.gguf", "--path", "/workdir/public", "--ctx-size", "2048", "-t", "8"]
