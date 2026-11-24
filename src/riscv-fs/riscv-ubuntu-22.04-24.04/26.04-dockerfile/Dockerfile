# Start from Ubuntu 26.04 base image
FROM ubuntu:26.04 AS stage1

# Install necessary packages for kernel and module build
RUN apt update && apt install -y \
    build-essential \
    libncurses-dev \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    bc \
    wget \
    git \
    kmod \
    python3 \
    cpio \
    rsync \
    dwarves \
    zstd \
    gcc-riscv64-linux-gnu

# Kbuild reads these from the environment, so every make call below
# (including the gem5_bridge one) cross-compiles for RISC-V
ENV ARCH=riscv
ENV CROSS_COMPILE=riscv64-linux-gnu-

RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources && apt update

WORKDIR /workspace
RUN apt source linux-image-unsigned-7.0.0-14-generic && \
    mv linux-*/ linux-src

RUN cd /workspace/linux-src && \
    make defconfig && \
    make -j"$(nproc)" && \
    make INSTALL_MOD_PATH=/workspace/output modules_install

RUN git clone https://github.com/gem5/gem5.git --depth=1 --filter=blob:none --no-checkout --sparse --single-branch --branch=stable && \
    cd gem5 && \
    git sparse-checkout add util/m5 util/gem5_bridge include && \
    git checkout

RUN cd gem5/util/gem5_bridge && \
    make KMAKEDIR=/workspace/linux-src INSTALL_MOD_PATH=/workspace/output build install

RUN rm -rf /workspace/output/lib/modules/*/build

FROM scratch AS export-stage
COPY --from=stage1 /workspace/output/lib/modules .
COPY --from=stage1 /workspace/linux-src/vmlinux .