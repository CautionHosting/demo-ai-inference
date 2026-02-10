FROM stagex/core-busybox@sha256:01b31cc07543733fbf6889e596427af943aba2780bc2f514a3d30bb290da7e2a AS core-busybox
FROM stagex/core-musl@sha256:23d0614f60449015add2369959c89a6ea08e208302773b9a0811ce1195afc3a4 AS core-musl
FROM stagex/core-gcc@sha256:02896413375c15cbff666fbab7c534caefc8936d53e167a6ea457a05c27e8096 AS core-gcc
FROM stagex/core-git@sha256:6b3e0055f6aeaa8465f207a871db2c63a939cd7406113e9d769ff3b37239f3d0 AS git
FROM stagex/core-ca-certificates@sha256:d135f1189e9b232eb7316626bf7858534c5540b2fc53dced80a4c9a95f26493e AS ca-certificates
FROM stagex/core-curl@sha256:bc8bab43d96a9167fbb85022ea773644a45ef335e7a9b747f203078973fa988e AS curl
FROM stagex/pallet-nodejs@sha256:1f705b58321b17e87ea68c04431ad83be6e6b64253d0443be4c61501902d57c3 AS pallet-nodejs
FROM stagex/pallet-gcc-cmake-busybox@sha256:41cd386c19d8a5b34bec3d929dfeee5c1967663e27e7fa81dde6d14b419ee95e AS pallet-gcc-cmake-busbox

FROM pallet-nodejs AS js-builder
COPY --from=git . /
COPY --from=ca-certificates . /
COPY --from=curl . /
WORKDIR /build/steve
RUN git clone --depth 1 https://git.distrust.co/public/steve.git .
WORKDIR /build/steve/steve-js-sdk
RUN npm install && npm run build
WORKDIR /build/attestation-widget
RUN git clone --depth 1 https://git.distrust.co/public/attestation-widget.git .

FROM pallet-gcc-cmake-busybox AS build
COPY --from=ca-certificates . /
COPY --from=curl . /
ARG VERSION=b4958
RUN curl -fsSL --retry 5 -o /llama.cpp.tar.gz https://github.com/ggerganov/llama.cpp/archive/refs/tags/${VERSION}.tar.gz && \
    tar -xzf /llama.cpp.tar.gz
WORKDIR /llama.cpp-${VERSION}
RUN <<-EOF
    set -eux
    mkdir -p .git
    touch .git/index
    cmake -B build -G Ninja \
        -DBUILD_TESTING=OFF \
        -DGGML_BUILD_NUMBER=1 \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_NATIVE=OFF \
        -DLLAMA_BUILD_EXAMPLES=ON \
        -DLLAMA_BUILD_SERVER=ON
    cmake --build build
    DESTDIR="/rootfs" cmake --install build
EOF

FROM pallet-gcc-cmake-busybox AS download
COPY --from=ca-certificates . /
COPY --from=curl . /
ARG MODEL_SHA256=d6d25bf078321bea4a079c727b273cb0b5a2e0b4cf3add0f7a2c8e43075c414f
RUN mkdir -p /models && \
    curl -fSL --retry 5 --retry-delay 10 -o /models/model.gguf \
    https://huggingface.co/bartowski/Phi-3.1-mini-4k-instruct-GGUF/resolve/main/Phi-3.1-mini-4k-instruct-Q4_K_M.gguf && \
        echo "${MODEL_SHA256}  /models/model.gguf" | sha256sum -c -


FROM scratch AS shell
COPY --from=core-busybox . /
COPY --from=core-musl . /
COPY --from=build /usr/lib/ /usr/lib

COPY --from=build /rootfs/ /
WORKDIR /workdir

COPY --from=download /models/model.gguf /workdir/models/model.gguf
COPY index.html /workdir/public/index.html
COPY --from=js-builder /build/steve/steve-js-sdk/dist/enclave-sw.js /workdir/public/enclave-sw.js
COPY --from=js-builder /build/steve/steve-js-sdk/dist/register.js /workdir/public/register.js
COPY --from=js-builder /build/attestation-widget/dist/index.js /workdir/public/attestation-widget.js

EXPOSE 8083

CMD ["/usr/bin/llama-server", "--host", "0.0.0.0", "--port", "8083", "-m", "/workdir/models/model.gguf", "--path", "/workdir/public", "--ctx-size", "4096"]
