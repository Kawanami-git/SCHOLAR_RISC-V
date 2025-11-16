#!/bin/sh
# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       install_sim_env.sh
# \brief      One-shot setup for the simulation toolchain (Verilator, GCC, Spike).
# \author     Kawanami
# \version    1.1
# \date       16/11/2025
#
# \details
#   Installs system dependencies and builds from source the following tools:
#     - Verilator (HDL simulator, pinned version v5.034)
#     - RISC-V GNU toolchains (rv32i_zicntr and rv64i_zicntr)
#     - Spike (RISC-V ISA simulator)
#   Targets standard Ubuntu environments with sudo privileges.
#
# \remarks
#   - Install locations:
#       /opt/verilator, /opt/riscv-gnu-toolchain, /opt/spike
#   - This script performs source builds; ensure enough disk/CPU resources.
#   - Adjust pinned versions if you need newer releases.
#
# \section install_sim_env_sh_version_history Version history
# | Version | Date       | Author     | Description      |
# |:-------:|:----------:|:-----------|:-----------------|
# | 1.0     | 11/11/2025 | Kawanami   | Initial version. |
# | 1.1     | 16/11/2025 | Kawanami   | Add 'graphviz' package for doxygen. |
# ********************************************************************************
# */

# --- Update package lists -------------------------------------------------------
sudo apt update

# --- Documentation tools (Doxygen for code docs) --------------------------------
sudo apt install -y doxygen graphviz

# --- Python & helpers (pyelftools/yaml used by build/util scripts) --------------
sudo apt install -y \
    python3 \
    python3-pip \
    python3-pyelftools \
    python3-yaml

# --- Verilator build dependencies ----------------------------------------------
sudo apt install -y \
    help2man \
    perl \
    make \
    autoconf \
    g++ \
    flex \
    bison \
    ccache \
    libgoogle-perftools-dev \
    numactl \
    perl-doc \
    libfl2 \
    libfl-dev \
    zlib1g \
    zlib1g-dev

# Target prefix for Verilator
sudo mkdir -p /opt/verilator/
sudo chown -R "$USER":"$USER" /opt/verilator/

# --- RISC-V toolchain (GCC/Newlib) deps ----------------------------------------
sudo apt install -y \
    autoconf \
    automake \
    autotools-dev \
    curl \
    python3 \
    python3-pip \
    libmpc-dev \
    libmpfr-dev \
    libgmp-dev \
    gawk \
    build-essential \
    bison \
    flex \
    texinfo \
    gperf \
    libtool \
    patchutils \
    bc \
    zlib1g-dev \
    libexpat-dev \
    ninja-build \
    git \
    cmake \
    libglib2.0-dev \
    libslirp-dev

# Install prefixes for the two multilib-free toolchains
sudo mkdir -p /opt/riscv-gnu-toolchain/
sudo chown -R "$USER":"$USER" /opt/riscv-gnu-toolchain/

# --- Spike ISA simulator deps ---------------------------------------------------
sudo apt install -y \
    device-tree-compiler \
    libboost-regex-dev \
    libboost-system-dev

# Target prefix for Spike
sudo mkdir -p /opt/spike/
sudo chown -R "$USER":"$USER" /opt/spike/

# ================================================================================
# Build Verilator (pinned to v5.034)
# ================================================================================
git clone https://github.com/verilator/verilator.git && \
cd verilator && \
git checkout v5.034 && \
autoconf && ./configure --prefix=/opt/verilator/ && \
make -j"$(nproc)" && make install && \
cd .. && rm -rf verilator

# ================================================================================
# Build RISC-V GNU Toolchain (two prefixes: rv32i_zicntr, rv64i_zicntr)
#   - Pinned to tag 2025.01.20 (adjust if needed)
#   - Newlib bare-metal toolchains with minimal ISA profiles used by SCHOLAR RISC-V
# ================================================================================
git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git && \
cd riscv-gnu-toolchain && \
git checkout 2025.01.20 && \
./configure --prefix=/opt/riscv-gnu-toolchain/rv32i_zicntr/ --with-arch=rv32i_zicntr --with-abi=ilp32 && \
make -j"$(nproc)" && \
make clean && \
./configure --prefix=/opt/riscv-gnu-toolchain/rv64i_zicntr/ --with-arch=rv64i_zicntr --with-abi=lp64 && \
make -j"$(nproc)" && \
cd .. && rm -rf riscv-gnu-toolchain

# ================================================================================
# Build Spike (ISA simulator)
# ================================================================================
git clone https://github.com/riscv-software-src/riscv-isa-sim.git && \
cd riscv-isa-sim && \
mkdir build && cd build && \
../configure --prefix=/opt/spike/ && \
make -j"$(nproc)" && make install && \
cd ../.. && rm -rf riscv-isa-sim
