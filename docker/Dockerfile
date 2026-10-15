FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake autopoint bison build-essential ca-certificates cmake curl file flex \
    gettext git gperf libtool nasm ninja-build patch perl pkg-config python3 re2c \
    rsync ruby unzip xz-utils zip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
ENTRYPOINT ["bash", "scripts/build.sh"]
CMD ["8.0"]
