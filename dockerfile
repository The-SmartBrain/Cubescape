FROM debian:stable

RUN apt update && apt install -y \
  build-essential \
  curl \
  libx11-dev \
  libxrandr-dev \
  libxinerama-dev \
  libxcursor-dev \
  libxi-dev \
  libxext-dev \
  libxfixes-dev \
  libgl1-mesa-dev

RUN curl -LO https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz \
  && tar -xf zig-x86_64-linux-0.15.2.tar.xz \
  && mv zig-x86_64-linux-0.15.2 /opt/zig \
  && ln -s /opt/zig/zig /usr/local/bin/zig

WORKDIR /workspace
