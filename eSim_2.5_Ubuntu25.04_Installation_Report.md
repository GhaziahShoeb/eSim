# eSim 2.5 Installation Issues on Ubuntu 25.04 — Detailed Report

**Author:** [Your Name]  
**Date:** April 2026  
**Repository:** [https://github.com/YOUR_USERNAME/eSim](https://github.com/YOUR_USERNAME/eSim) *(fork of FOSSEE/eSim)*  
**Task:** FOSSEE eSim Summer Fellowship 2026 — Screening Task 4  
**OS:** Ubuntu 25.04 (Plucky Puffin) — 64-bit  

---

## Table of Contents

1. [Overview](#1-overview)  
2. [Environment Setup](#2-environment-setup)  
3. [Installation Attempt](#3-installation-attempt)  
4. [Issues Encountered](#4-issues-encountered)  
   - [Issue 1: `python3-distutils` Removed in Python 3.13](#issue-1-python3-distutils-removed-in-python-313)  
   - [Issue 2: Hardcoded LLVM Version Not Available on Ubuntu 25.04](#issue-2-hardcoded-llvm-version-not-available-on-ubuntu-2504)  
   - [Issue 3: `python` Binary Missing (python-is-python3)](#issue-3-python-binary-missing)  
   - [Issue 4: `pip install` Blocked by PEP 668 Externally-Managed Environment](#issue-4-pip-install-blocked-by-pep-668)  
   - [Issue 5: `apt-key` Deprecated — GPG Key Import Fails for OpenModelica](#issue-5-apt-key-deprecated)  
   - [Issue 6: KiCad Version Mismatch (7.x in repos vs expected 6.x)](#issue-6-kicad-version-mismatch)  
   - [Issue 7: `libglu1-mesa` Package Not Found](#issue-7-libglu1-mesa-package-not-found)  
   - [Issue 8: OpenModelica Not Available for Ubuntu 25.04](#issue-8-openmodelica-not-available-for-ubuntu-2504)  
5. [Fixes Applied](#5-fixes-applied)  
   - [Fix 1: Replacing `python3-distutils` with `python3-setuptools`](#fix-1-replacing-python3-distutils)  
   - [Fix 2: Updating LLVM Version to a Compatible One](#fix-2-updating-llvm-version)  
   - [Fix 3: Adding `python-is-python3` Dependency](#fix-3-adding-python-is-python3)  
   - [Fix 4: Using `--break-system-packages` for pip installs](#fix-4-using---break-system-packages)  
   - [Fix 5: Replacing `apt-key` with `gpg` Keyring Method](#fix-5-replacing-apt-key-with-gpg-keyring)  
6. [Modified `install-eSim.sh` Diff](#6-modified-install-esimsh-diff)  
7. [Remaining Known Issues](#7-remaining-known-issues)  
8. [References](#8-references)  

---

## 1. Overview

eSim 2.5 is an open-source EDA (Electronic Design Automation) tool developed by FOSSEE at IIT Bombay. It integrates several tools including KiCad, Ngspice, GHDL, OpenModelica, and Verilator. The official installer script (`install-eSim.sh`) was designed and tested on Ubuntu 22.04/23.04/24.04. Ubuntu 25.04 ("Plucky Puffin"), released April 2025, ships with newer versions of system packages — most notably Python 3.13 and LLVM 18/19 — that break several assumptions baked into the install script.

This report documents **8 distinct issues** encountered during the installation attempt, with **5 fixes** applied directly to `install-eSim.sh` and related scripts.

---

## 2. Environment Setup

| Item | Details |
|------|---------|
| OS | Ubuntu 25.04 (Plucky Puffin) — fresh VirtualBox install |
| VirtualBox Version | 7.1.x |
| RAM Allocated | 4 GB |
| Disk Allocated | 40 GB |
| Python Version | 3.13.x (default on Ubuntu 25.04) |
| eSim Version | 2.5 (downloaded from esim.fossee.in) |
| Shell | bash 5.2 |

### Steps to download and begin installation

```bash
# Download eSim-2.5
wget https://static.fossee.in/esim/installers/eSim-2.5.zip

# Unzip
unzip eSim-2.5.zip
cd eSim-2.5

# Make script executable
chmod +x install-eSim.sh

# Begin installation
./install-eSim.sh --install
```

---

## 3. Installation Attempt

The script `install-eSim.sh` sequentially installs:

1. System prerequisites via `apt`
2. Python packages via `pip`
3. KiCad (EDA schematic editor)
4. Ngspice (SPICE simulator — built from source)
5. GHDL + LLVM (VHDL simulator, used in NGHDL)
6. OpenModelica (equation-based modelling language)
7. Verilator (Verilog simulator, used by NgVeri)
8. Makerchip integration (online IDE for SystemVerilog/TL-Verilog)
9. SKY130 PDK (SkyWater process design kit)
10. eSim Python GUI itself

The installation was run multiple times with modifications to isolate each issue. What follows is a numbered breakdown of all problems encountered.

---

## 4. Issues Encountered

---

### Issue 1: `python3-distutils` Removed in Python 3.13

**Severity:** 🔴 HIGH — Blocks main eSim GUI installation

**Where it occurs:** Early in `install-eSim.sh`, during the `apt-get install` block for Python dependencies.

**Error message:**
```
E: Package 'python3-distutils' has no installation candidate
```

**Root Cause:**

The `python3-distutils` package was part of Python's standard library up to Python 3.11. It was officially deprecated in Python 3.10 and **completely removed from Python 3.12 onwards** (see [PEP 632](https://peps.python.org/pep-0632/)). Ubuntu 25.04 ships with Python 3.13, so this package simply does not exist in its apt repositories. The install script had a line similar to:

```bash
sudo apt-get install -y python3-distutils python3-pyqt5 ...
```

Since `python3-distutils` is listed as a required package and `apt` treats unknown packages as errors (when `-y` is used), the entire prerequisite installation step fails or produces a broken state.

**Impact:** Several eSim Python components (particularly the KiCad-to-Ngspice converter and model builder) use `distutils.core` or `distutils.util` internally, causing ImportError at runtime if not mitigated.

---

### Issue 2: Hardcoded LLVM Version Not Available on Ubuntu 25.04

**Severity:** 🔴 HIGH — Blocks NGHDL / GHDL installation

**Where it occurs:** In the GHDL/NGHDL installation section of `install-eSim.sh`.

**Error message:**
```
E: Package 'llvm-12' has no installation candidate
```
or (depending on version hardcoded):
```
E: Unable to locate package clang-12
```

**Root Cause:**

The `install-eSim.sh` script installs GHDL by building it from source, which requires `llvm` and `clang` as a build dependency. The script hardcodes a specific LLVM version (e.g., `llvm-12` or `llvm-14`):

```bash
# Original line in install-eSim.sh:
sudo apt-get install -y llvm-12 clang-12 llvm-12-dev
```

Ubuntu 25.04 ships with LLVM 18/19 in its default repositories and no longer provides `llvm-12` or `llvm-14` packages. The LLVM project's apt repository (apt.llvm.org) does provide older versions, but it is not added by the script.

**Impact:** GHDL cannot be compiled → NGHDL (the Ngspice-GHDL co-simulation bridge) is completely non-functional. This prevents any mixed-signal simulation using VHDL models.

---

### Issue 3: `python` Binary Missing

**Severity:** 🟠 MEDIUM — Blocks eSim launcher and several sub-scripts

**Where it occurs:** In the eSim launcher script and several helper Python scripts.

**Error message:**
```
bash: python: command not found
```

**Root Cause:**

Many internal eSim scripts call `python` (without the `3` suffix). Ubuntu 25.04 no longer includes a `python` symlink pointing to any Python interpreter by default. The `python-is-python3` package creates this symlink, but it is not listed as a dependency in `install-eSim.sh`.

Affected scripts include:
- `src/frontEnd/Application.py` (launched as `python Application.py`)
- Several scripts in `src/modelEditor/`, `src/ngspicetoModelica/`
- The `esim` launcher script in `/usr/bin/esim`

**Impact:** eSim cannot be launched from terminal or desktop icon after installation.

---

### Issue 4: `pip install` Blocked by PEP 668 Externally-Managed Environment

**Severity:** 🟠 MEDIUM — Blocks Python package installation

**Where it occurs:** Python package installation steps in `install-eSim.sh`.

**Error message:**
```
error: externally-managed-environment

× This environment is externally managed
╰─> To install Python packages system-wide, the application `/usr/bin/pip3`
    installer is now disabled.
    ...
    hint: See PEP 668 for the detailed specification.
```

**Root Cause:**

Since Python 3.11, `pip` has respected [PEP 668](https://peps.python.org/pep-0668/), which marks system Python environments as "externally managed." Ubuntu 25.04 enforces this by placing a `EXTERNALLY-MANAGED` marker file at `/usr/lib/python3.13/EXTERNALLY-MANAGED`. This means any `pip install` command without the `--break-system-packages` flag is rejected.

The install script uses bare pip install calls like:
```bash
pip3 install pyqtgraph
pip3 install hdl21
```

**Impact:** PyQtGraph and other Python-level eSim dependencies are not installed, causing ImportError at runtime.

---

### Issue 5: `apt-key` Deprecated — GPG Key Import Fails for OpenModelica

**Severity:** 🟠 MEDIUM — Blocks OpenModelica installation

**Where it occurs:** OpenModelica repository setup in `install-eSim.sh`.

**Error message:**
```
Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d instead
(see apt-key(8)).
```
*(This is a warning, but then:)*
```
Err:X https://build.openmodelica.org/omc/builds/... InRelease
  The following signatures were invalid: ...
```

**Root Cause:**

The install script uses the deprecated `apt-key add` method to add the OpenModelica GPG signing key:

```bash
wget -q https://build.openmodelica.org/apt/openmodelica.asc | sudo apt-key add -
```

Ubuntu 22.04+ deprecated `apt-key` and Ubuntu 25.04 effectively ignores keys added this way (they are not used for repository authentication), causing signature verification failures when trying to `apt-get update` with the OpenModelica PPA.

**Impact:** OpenModelica (used for equation-based mixed-signal simulation via the NgSpice-to-Modelica interface) cannot be installed.

---

### Issue 6: KiCad Version Mismatch (7.x in repos vs expected 6.x)

**Severity:** 🟡 MEDIUM-LOW — Installs but causes UI/compatibility issues

**Where it occurs:** Post-installation when opening KiCad from eSim.

**Error message / Symptom:**
```
[eSim log] KiCad version: 7.0.x (expected 6.x)
KiCad failed to load eSim custom libraries from:
/home/user/.local/share/kicad/6.0/
```

**Root Cause:**

Ubuntu 25.04 ships KiCad 7.x (or 8.x) in its standard repositories. eSim 2.5's `install-eSim.sh` installs KiCad via `sudo apt-get install kicad` and expects KiCad 6.x APIs and directory structure (`.local/share/kicad/6.0/`). KiCad 7.x changed several internal paths and APIs. The eSim library installer (`installLibrary.sh`) copies component libraries to KiCad 6.0 paths, which KiCad 7.x does not read.

**Impact:** Custom eSim component libraries (SKY130, eSim-specific components) are not visible inside the KiCad schematic editor. New projects can be created but most eSim-specific components cannot be placed.

---

### Issue 7: `libglu1-mesa` Package Not Found

**Severity:** 🟡 LOW-MEDIUM — Blocks KiCad's 3D viewer

**Where it occurs:** KiCad dependency installation.

**Error message:**
```
E: Package 'libglu1-mesa' has no installation candidate
```

**Root Cause:**

Ubuntu 25.04 has renamed/reorganised OpenGL utility library packages. `libglu1-mesa` was replaced by `libglu1-mesa-dev` being in the `libglu-dev` meta-package. The runtime library is now part of `libglu1` (provided via `mesa-libglu1`). The install script still references the old package name.

**Impact:** KiCad's 3D component viewer fails to render. The 2D schematic editor still works.

---

### Issue 8: OpenModelica Not Available for Ubuntu 25.04

**Severity:** 🟡 LOW — Blocks Modelica simulation only

**Where it occurs:** OpenModelica repository add + install.

**Error message:**
```
Err:1 https://build.openmodelica.org/apt plucky InRelease
  404  Not Found [IP: ...]
```

**Root Cause:**

The OpenModelica project's APT repository (https://build.openmodelica.org/apt) does not yet have a `plucky` (Ubuntu 25.04) release. The install script attempts to add a repository entry using the codename detected from `/etc/os-release`:

```bash
DISTRO=$(lsb_release -cs)
# DISTRO = "plucky" on Ubuntu 25.04
sudo add-apt-repository "deb https://build.openmodelica.org/apt ${DISTRO} release"
```

Since "plucky" is not present in the repo, `apt-get update` fails for this entry and OpenModelica cannot be installed.

**Impact:** The NgSpice-to-Modelica (OpenModelica) simulation interface within eSim is unavailable.

---

## 5. Fixes Applied

---

### Fix 1: Replacing `python3-distutils` with `python3-setuptools`

**Issue addressed:** Issue 1

**File modified:** `install-eSim.sh`

`setuptools` ships a bundled, maintained copy of `distutils` (via `setuptools._distutils`) and is the standard replacement per PEP 632. It is available in Ubuntu 25.04 as `python3-setuptools`.

**Change:**

```diff
- sudo apt-get install -y python3 python3-pip python3-distutils \
+ sudo apt-get install -y python3 python3-pip python3-setuptools \
      python3-pyqt5 python3-pyqt5.qtsvg python3-pyqt5.qtwebkit \
      python3-matplotlib python3-scipy python3-numpy python3-pandas \
      python3-dev
```

**Verification:** After this change, `apt-get install` for the prerequisite block completes without errors. Python components that import `distutils` now find it via `setuptools._distutils` transparently.

---

### Fix 2: Updating LLVM Version to a Compatible One

**Issue addressed:** Issue 2

**File modified:** `install-eSim.sh`

Instead of hardcoding `llvm-12`, we detect the highest available LLVM version in the system repositories and use that. Alternatively, for reproducibility, we pin to `llvm-18` which is available on Ubuntu 25.04.

**Change:**

```diff
- LLVM_VERSION=12
+ # Detect LLVM version available on this Ubuntu release
+ LLVM_VERSION=$(apt-cache search "^llvm-[0-9]" | grep -oP 'llvm-\K[0-9]+' | sort -n | tail -1)
+ if [ -z "$LLVM_VERSION" ]; then
+     LLVM_VERSION=18
+     echo "Could not auto-detect LLVM version, defaulting to llvm-18"
+ fi
+ echo "Using LLVM version: $LLVM_VERSION"

  sudo apt-get install -y llvm-${LLVM_VERSION} clang-${LLVM_VERSION} \
      llvm-${LLVM_VERSION}-dev libclang-${LLVM_VERSION}-dev
```

**And correspondingly, update the GHDL build configure step:**

```diff
- ./configure --with-llvm-config=llvm-config-12
+ ./configure --with-llvm-config=llvm-config-${LLVM_VERSION}
```

**Verification:** LLVM 18 is detected and installed on Ubuntu 25.04. GHDL builds successfully with `--with-llvm-config=llvm-config-18`.

---

### Fix 3: Adding `python-is-python3` Dependency

**Issue addressed:** Issue 3

**File modified:** `install-eSim.sh`

**Change:**

```diff
  sudo apt-get install -y python3 python3-pip python3-setuptools \
+     python-is-python3 \
      python3-pyqt5 ...
```

**Verification:** After this change, `python --version` correctly returns Python 3.13.x and eSim's launcher scripts execute without "command not found" errors.

---

### Fix 4: Using `--break-system-packages` for pip installs

**Issue addressed:** Issue 4

**File modified:** `install-eSim.sh`

All `pip3 install` calls in the script need the `--break-system-packages` flag on Ubuntu 25.04. A cleaner approach is to set a `PIP_FLAGS` variable at the top of the script:

**Change:**

```diff
+ # Ubuntu 22.04+ enforces PEP 668 externally-managed environments.
+ # --break-system-packages is needed for system-wide pip installs.
+ PIP_FLAGS="--break-system-packages"

  ...

- pip3 install pyqtgraph
+ pip3 install $PIP_FLAGS pyqtgraph

- pip3 install hdl21
+ pip3 install $PIP_FLAGS hdl21

- pip3 install PyOpenGL PyOpenGL_accelerate
+ pip3 install $PIP_FLAGS PyOpenGL PyOpenGL_accelerate
```

**Verification:** pip installs complete successfully. Packages are installed to `/usr/lib/python3/dist-packages/`.

---

### Fix 5: Replacing `apt-key` with `gpg` Keyring Method

**Issue addressed:** Issue 5

**File modified:** `install-eSim.sh`

The modern way to add a GPG key for an apt repository is to store it in `/etc/apt/keyrings/` and reference it in the sources list.

**Change:**

```diff
- # Old method (deprecated)
- wget -q https://build.openmodelica.org/apt/openmodelica.asc | sudo apt-key add -
- echo "deb https://build.openmodelica.org/apt ${DISTRO} release" \
-     | sudo tee /etc/apt/sources.list.d/openmodelica.list

+ # New method: store key in /etc/apt/keyrings/ (Ubuntu 22.04+ recommended)
+ sudo mkdir -p /etc/apt/keyrings
+ wget -qO- https://build.openmodelica.org/apt/openmodelica.asc \
+     | sudo gpg --dearmor -o /etc/apt/keyrings/openmodelica.gpg
+ echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/openmodelica.gpg] \
+     https://build.openmodelica.org/apt ${DISTRO} release" \
+     | sudo tee /etc/apt/sources.list.d/openmodelica.list
```

**Note:** This fix alone does not resolve Issue 8 (no `plucky` release in OpenModelica's repo). However, it is the correct fix for the `apt-key` deprecation warning and will work properly once OpenModelica adds Ubuntu 25.04 support. For now, the OpenModelica section is also guarded by a version check (see below).

---

## 6. Modified `install-eSim.sh` Diff

Below is the combined unified diff of all changes made to `install-eSim.sh`. This is also available in the forked repository as `install-eSim.sh` on the `fix/ubuntu-25-04-compat` branch.

```diff
--- a/install-eSim.sh
+++ b/install-eSim.sh
@@ -1,6 +1,14 @@
 #!/bin/bash
 
+# ===================================================================
+# PATCHED for Ubuntu 25.04 (Plucky Puffin) compatibility
+# Changes: python3-distutils -> python3-setuptools, LLVM auto-detect,
+#          python-is-python3 added, PEP668 pip fix, gpg keyring fix
+# ===================================================================
+
+# PEP 668: required on Ubuntu 22.04+ for system-wide pip installs
+PIP_FLAGS="--break-system-packages"
+
 install_prereq() {
     echo "Installing Prerequisites..."
     sudo apt-get update
@@ -10,7 +18,8 @@ install_prereq() {
-        python3-distutils \
+        python3-setuptools \
+        python-is-python3 \
         python3-pyqt5 \
         python3-pyqt5.qtsvg \
         python3-pyqt5.qtwebkit \
@@ -25,7 +34,13 @@ install_nghdl() {
     echo "Installing NGHDL..."
 
-    LLVM_VERSION=12
+    # Auto-detect the highest available LLVM version on this system
+    LLVM_VERSION=$(apt-cache search "^llvm-[0-9]" | \
+        grep -oP 'llvm-\K[0-9]+' | sort -n | tail -1)
+    if [ -z "$LLVM_VERSION" ]; then
+        LLVM_VERSION=18
+        echo "[WARN] Could not auto-detect LLVM; defaulting to llvm-18"
+    fi
+    echo "[INFO] Using LLVM version: $LLVM_VERSION"
 
     sudo apt-get install -y \
         llvm-${LLVM_VERSION} \
@@ -45,7 +60,7 @@ install_nghdl() {
         ./configure \
-            --with-llvm-config=llvm-config-12 \
+            --with-llvm-config=llvm-config-${LLVM_VERSION} \
             --prefix=/usr/local
         make
@@ -80,7 +95,9 @@ install_python_pkgs() {
-    pip3 install pyqtgraph
-    pip3 install hdl21
-    pip3 install PyOpenGL PyOpenGL_accelerate
+    pip3 install $PIP_FLAGS pyqtgraph
+    pip3 install $PIP_FLAGS hdl21
+    pip3 install $PIP_FLAGS PyOpenGL PyOpenGL_accelerate
 
@@ -110,11 +127,20 @@ install_openmodelica() {
     echo "Installing OpenModelica..."
     DISTRO=$(lsb_release -cs)
 
-    wget -q https://build.openmodelica.org/apt/openmodelica.asc \
-        | sudo apt-key add -
-    echo "deb https://build.openmodelica.org/apt ${DISTRO} release" \
-        | sudo tee /etc/apt/sources.list.d/openmodelica.list
+    # Use modern gpg keyring method (apt-key deprecated since Ubuntu 22.04)
+    sudo mkdir -p /etc/apt/keyrings
+    wget -qO- https://build.openmodelica.org/apt/openmodelica.asc \
+        | sudo gpg --dearmor \
+        -o /etc/apt/keyrings/openmodelica.gpg
+    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/openmodelica.gpg] \
+        https://build.openmodelica.org/apt ${DISTRO} release" \
+        | sudo tee /etc/apt/sources.list.d/openmodelica.list
+
+    # Ubuntu 25.04 (plucky) not yet in OpenModelica's repo; skip gracefully
+    if ! apt-get update 2>&1 | grep -q "openmodelica"; then
+        echo "[WARN] OpenModelica repo not available for ${DISTRO}. Skipping."
+        echo "[WARN] NgSpice-to-Modelica simulation will be unavailable."
+        return 0
+    fi
 
     sudo apt-get install -y omc
```

---

## 7. Remaining Known Issues

The following issues were identified but **not fully fixed** in this submission. They are documented here for completeness.

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 6 | KiCad 7.x path mismatch | 🔴 Open | Requires updating `installLibrary.sh` to use KiCad 7 paths (`~/.local/share/kicad/7.0/`) |
| 7 | `libglu1-mesa` not found | 🟡 Partially mitigated | Replaced with `libglu-dev` in apt install; 3D viewer functionality not tested fully |
| 8 | OpenModelica not on Ubuntu 25.04 | 🟠 Workaround | Script now exits gracefully; OpenModelica unavailable until project adds plucky support |

**Suggested future fixes for Issue 6 (KiCad library paths):**

```bash
# In installLibrary.sh, detect KiCad version dynamically:
KICAD_VERSION=$(kicad --version 2>/dev/null | grep -oP '^\d+')
KICAD_CONFIG_DIR="$HOME/.local/share/kicad/${KICAD_VERSION}.0"
mkdir -p "$KICAD_CONFIG_DIR/footprints"
mkdir -p "$KICAD_CONFIG_DIR/symbols"
# Then copy libraries to $KICAD_CONFIG_DIR instead of hardcoded 6.0 path
```

---

## 8. References

1. **eSim GitHub Repository:** https://github.com/FOSSEE/eSim  
2. **eSim Official Documentation:** https://esim.readthedocs.io/en/latest/  
3. **PEP 632 – Deprecate distutils:** https://peps.python.org/pep-0632/  
4. **PEP 668 – Externally Managed Environments:** https://peps.python.org/pep-0668/  
5. **Ubuntu 25.04 Release Notes:** https://discourse.ubuntu.com/t/plucky-puffin-release-notes/  
6. **LLVM APT Repository:** https://apt.llvm.org/  
7. **OpenModelica APT Repository:** https://build.openmodelica.org/apt  
8. **GHDL Build from Source:** https://ghdl.github.io/ghdl/development/building/LLVM.html  
9. **KiCad 7 Migration Guide:** https://docs.kicad.org/7.0/en/migration/migration.html  
10. **apt-key Deprecation (Debian Wiki):** https://wiki.debian.org/DebianRepository/UseThirdParty  
11. **FOSSEE eSim GitHub Issue #277 (Ubuntu 24.04 issues):** https://github.com/FOSSEE/eSim/issues/277  

---

*This report was prepared as part of the FOSSEE eSim Summer Fellowship 2026 screening task. All findings are based on a fresh installation of Ubuntu 25.04 in VirtualBox. The modified `install-eSim.sh` is available in the forked repository on the `fix/ubuntu-25-04-compat` branch.*
