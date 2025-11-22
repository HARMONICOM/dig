FROM debian:trixie-20251020-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    default-libmysqlclient-dev \
    libpq-dev \
    pkg-config \
    xz-utils

RUN apt-get clean && apt-get purge && apt-get autoremove --purge -y && \
    rm -rf /var/lib/apt/lists/*

ARG ZIG_VERSION="0.15.2"
RUN curl -sSL -O https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz && \
    tar Jxf zig-x86_64-linux-${ZIG_VERSION}.tar.xz -C /usr/local && \
    mv /usr/local/zig-x86_64-linux-${ZIG_VERSION} /usr/local/zig && \
    rm -rf zig-x86_64-linux-${ZIG_VERSION}.tar.xz
RUN chown -R root:root /usr/local/zig && \
    rm -rf /usr/local/zig/.git
ENV PATH="${PATH}:/usr/local/zig"
ENV ZIG_LOCAL_CACHE_DIR="/tmp"

WORKDIR /usr/src/app
