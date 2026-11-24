# Start from Ubuntu 26.04 base image
FROM ubuntu:26.04 AS stage1

# Install necessary packages for kernel and module build
# RUN apt update && apt install -y \
#     build-essential \
#     libncurses-dev \
#     bison \
#     flex \
#     libssl-dev \
#     libelf-dev \
#     bc \
#     wget \
#     git \
#     kmod

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
    zstd

# RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
RUN apt update
RUN mkdir /workspace 
# RUN cd /workspace && apt source linux-image-unsigned-7.0.0-14-generic

# RUN ls /workspace
# RUN cd /workspace/linux-hwe-7.0-7.0.0 && \
#     make defconfig && \
#     make -j 20 && \
#     make INSTALL_MOD_PATH=/workspace/output modules_install

# RUN git clone https://github.com/gem5/gem5.git --depth=1 --filter=blob:none --no-checkout --sparse --single-branch --branch=stable && \
#     cd gem5 && \
#     git sparse-checkout add util/m5 && \
#     git sparse-checkout add util/gem5_bridge && \
#     git sparse-checkout add include && \
#     git checkout

# RUN cd gem5/util/gem5_bridge && \
#     make KMAKEDIR=/workspace/linux-hwe-7.0-7.0.0 INSTALL_MOD_PATH=/workspace/output build install

# RUN cd /workspace/output/lib/modules/7.0.0 && \
#     rm -rf build

# FROM scratch AS export-stage
# COPY --from=stage1 /workspace/output/lib/modules .
# COPY --from=stage1 /workspace/linux-hwe-7.0-7.0.0/vmlinux .

RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources && apt update

WORKDIR /workspace
RUN apt source linux-image-unsigned-7.0.0-14-generic && \
    mv linux-*/ linux-src && \
    ls -la /workspace

RUN cd /workspace/linux-src && \
    make defconfig && \
    make -j"$(nproc)" && \
    make INSTALL_MOD_PATH=/workspace/output modules_install
# RUN cd /workspace/linux-src && \
#     make defconfig && \
#     (make -j"$(nproc)" || make -j1) && \
#     make INSTALL_MOD_PATH=/workspace/output modules_install

RUN git clone https://github.com/gem5/gem5.git --depth=1 --filter=blob:none --no-checkout --sparse --single-branch --branch=stable && \
    cd gem5 && \
    git sparse-checkout add util/m5 util/gem5_bridge include && \
    git checkout

RUN cd gem5/util/gem5_bridge && \
    make KMAKEDIR=/workspace/linux-src INSTALL_MOD_PATH=/workspace/output build install

# Don't hardcode the kernel release string either
RUN rm -rf /workspace/output/lib/modules/*/build

FROM scratch AS export-stage
COPY --from=stage1 /workspace/output/lib/modules .
COPY --from=stage1 /workspace/linux-src/vmlinux .