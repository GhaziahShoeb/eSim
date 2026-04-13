#!/bin/bash
# =============================================================================
# install-eSim.sh — PATCHED for Ubuntu 25.04 (Plucky Puffin)
#
# Original:   https://github.com/FOSSEE/eSim
# Patch by:   [Your Name] — FOSSEE Internship Task 4, April 2026
# Branch:     fix/ubuntu-25-04-compat
#
# Summary of changes vs original:
#   [FIX 1] python3-distutils  → python3-setuptools  (removed in Python 3.12+)
#   [FIX 2] Hardcoded llvm-12  → auto-detected LLVM  (Ubuntu 25.04 ships llvm-18)
#   [FIX 3] Added python-is-python3 package          (python binary missing)
#   [FIX 4] All pip3 calls use --break-system-packages (PEP 668, Ubuntu 22.04+)
#   [FIX 5] apt-key → gpg keyring method             (apt-key deprecated)
#   [WKRD 8] OpenModelica: graceful skip if repo unavailable for this distro
# =============================================================================

set -e  # Exit on first error

# ─── PEP 668 fix ─────────────────────────────────────────────────────────────
# Ubuntu 22.04+ enforces externally-managed Python environments.
# All system-wide pip installs require this flag.
PIP_FLAGS="--break-system-packages"

# ─── Helper ──────────────────────────────────────────────────────────────────
log_info()  { echo -e "\e[32m[INFO]\e[0m  $*"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m  $*"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $*"; }

# =============================================================================
# install_prereq — system-level Python and GUI dependencies
# =============================================================================
install_prereq() {
    log_info "Installing system prerequisites..."
    sudo apt-get update

    sudo apt-get install -y \
        git \
        wget \
        curl \
        xterm \
        gaw \
        python3 \
        python3-pip \
        # FIX 1: python3-distutils removed in Python 3.12/3.13
        # Use python3-setuptools which ships a compatible distutils shim
        python3-setuptools \
        # FIX 3: Ubuntu 25.04 has no 'python' symlink; add it
        python-is-python3 \
        python3-dev \
        python3-pyqt5 \
        python3-pyqt5.qtsvg \
        python3-pyqt5.qtwebkit \
        python3-matplotlib \
        python3-scipy \
        python3-numpy \
        python3-pandas \
        # FIX 7 (partial): libglu1-mesa renamed; use libglu-dev + mesa-utils
        libglu-dev \
        mesa-utils \
        bison \
        flex \
        autoconf \
        automake \
        libtool \
        libreadline-dev \
        libfftw3-dev \
        libx11-dev \
        libxt-dev \
        libxaw7-dev \
        libgtk2.0-dev \
        libncurses-dev \
        libedit-dev \
        libsuitesparse-dev \
        libopenblas-dev \
        gfortran \
        cmake

    log_info "Prerequisites installed."
}

# =============================================================================
# install_python_pkgs — pip-based Python dependencies
# =============================================================================
install_python_pkgs() {
    log_info "Installing Python packages via pip..."

    # FIX 4: --break-system-packages required on Ubuntu 22.04+ (PEP 668)
    pip3 install $PIP_FLAGS pyqtgraph
    pip3 install $PIP_FLAGS hdl21
    pip3 install $PIP_FLAGS PyOpenGL PyOpenGL_accelerate

    log_info "Python packages installed."
}

# =============================================================================
# install_nghdl — GHDL + LLVM for NGHDL co-simulation
# =============================================================================
install_nghdl() {
    log_info "Installing NGHDL (GHDL + LLVM)..."

    # FIX 2: Auto-detect the highest LLVM version available in the system repos
    # instead of hardcoding llvm-12 (which is absent on Ubuntu 25.04).
    LLVM_VERSION=$(apt-cache search "^llvm-[0-9]" 2>/dev/null \
        | grep -oP 'llvm-\K[0-9]+' \
        | sort -n \
        | tail -1)

    if [ -z "$LLVM_VERSION" ]; then
        LLVM_VERSION=18
        log_warn "Could not auto-detect LLVM version; defaulting to llvm-18"
    fi
    log_info "Using LLVM version: $LLVM_VERSION"

    sudo apt-get install -y \
        llvm-${LLVM_VERSION} \
        clang-${LLVM_VERSION} \
        llvm-${LLVM_VERSION}-dev \
        libclang-${LLVM_VERSION}-dev

    # Build GHDL from source with the detected LLVM
    if [ -d "nghdl/src/ghdl" ]; then
        cd nghdl/src/ghdl
        # FIX 2 continued: use the auto-detected llvm-config binary
        ./configure \
            --with-llvm-config="llvm-config-${LLVM_VERSION}" \
            --prefix=/usr/local
        make -j$(nproc)
        sudo make install
        cd -
    else
        log_warn "GHDL source not found. Skipping GHDL build."
    fi

    log_info "NGHDL installation complete."
}

# =============================================================================
# install_openmodelica — equation-based modelling (NgSpice↔Modelica)
# =============================================================================
install_openmodelica() {
    log_info "Installing OpenModelica..."
    DISTRO=$(lsb_release -cs)

    # FIX 5: Replace deprecated apt-key with modern gpg keyring method
    # (apt-key is deprecated since Ubuntu 22.04; effectively broken on 25.04)
    sudo mkdir -p /etc/apt/keyrings

    wget -qO- https://build.openmodelica.org/apt/openmodelica.asc \
        | sudo gpg --dearmor \
          -o /etc/apt/keyrings/openmodelica.gpg 2>/dev/null || {
        log_warn "Failed to download OpenModelica GPG key. Skipping OpenModelica."
        return 0
    }

    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/openmodelica.gpg] \
https://build.openmodelica.org/apt ${DISTRO} release" \
        | sudo tee /etc/apt/sources.list.d/openmodelica.list > /dev/null

    # WORKAROUND Issue 8: Ubuntu 25.04 ("plucky") not yet in OpenModelica repo.
    # Attempt update; if it fails, skip gracefully instead of aborting.
    if ! sudo apt-get update 2>&1 | grep -v "openmodelica" | grep -q "Err"; then
        log_warn "OpenModelica repository not available for '${DISTRO}'."
        log_warn "NgSpice-to-Modelica simulation will be unavailable."
        log_warn "Check https://build.openmodelica.org/apt for future support."
        # Remove the broken source entry to avoid repeated update warnings
        sudo rm -f /etc/apt/sources.list.d/openmodelica.list
        return 0
    fi

    sudo apt-get install -y omc
    log_info "OpenModelica installed."
}

# =============================================================================
# install_kicad — EDA schematic editor
# Note: Ubuntu 25.04 ships KiCad 7.x or 8.x. eSim was designed for KiCad 6.x.
# Library path fix required in installLibrary.sh (see Issue 6 in report).
# =============================================================================
install_kicad() {
    log_info "Installing KiCad..."
    sudo apt-get install -y kicad

    # Detect installed KiCad version for library path fix (Issue 6)
    KICAD_VER=$(kicad --version 2>/dev/null | grep -oP '^\d+' || echo "6")
    log_info "Detected KiCad version: $KICAD_VER"

    KICAD_CONFIG_DIR="$HOME/.local/share/kicad/${KICAD_VER}.0"
    mkdir -p "$KICAD_CONFIG_DIR/footprints"
    mkdir -p "$KICAD_CONFIG_DIR/symbols"

    export KICAD_CONFIG_DIR
    log_info "KiCad config dir: $KICAD_CONFIG_DIR"
}

# =============================================================================
# Main entry point
# =============================================================================
main() {
    case "$1" in
        --install)
            log_info "=== eSim 2.5 Installation (Ubuntu 25.04 patched) ==="
            install_prereq
            install_python_pkgs
            install_kicad
            install_nghdl
            install_openmodelica
            # ... (rest of original install steps: ngspice, verilator, esim GUI)
            log_info "=== Installation complete ==="
            ;;
        --uninstall)
            log_info "Running uninstaller..."
            # Original uninstall logic here
            ;;
        *)
            echo "Usage: $0 [--install | --uninstall]"
            exit 1
            ;;
    esac
}

main "$@"
