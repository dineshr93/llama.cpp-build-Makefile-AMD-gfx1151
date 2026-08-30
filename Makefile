# =============================================================================
# Generic llama.cpp Makefile
#
# Target:
#   AMD Ryzen AI Max+ 395
#   AMD Radeon 8060S
#   gfx1151
#   Ubuntu Linux
#
# Supports:
#   - ggml-org/llama.cpp
#   - llama.cpp forks based on current upstream
#
# Backends:
#   ROCm / HIP
#   Vulkan
#
# IMPORTANT:
#   "make" with no arguments displays all available commands.
#
# =============================================================================

SHELL := /bin/bash

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

BUILD_TYPE ?= Release
JOBS       ?= $(shell nproc)

GPU_TARGETS ?= gfx1151

ROCM_PATH ?= /opt/rocm

# Let ROCm determine the correct clang installation.
HIPCXX ?= $(shell command -v hipcc >/dev/null 2>&1 && hipconfig -l 2>/dev/null)/clang
HIP_PATH ?= $(shell hipconfig -R 2>/dev/null)

PROJECT_DIR := $(CURDIR)

# -----------------------------------------------------------------------------
# Directories
# -----------------------------------------------------------------------------

ROCM_BUILD   := build-rocm
VULKAN_BUILD := build-vulkan

# -----------------------------------------------------------------------------
# Common llama.cpp configuration
#
# DO NOT set GGML_BUILD_EXAMPLES=ON.
#
# ggml/examples does not exist in the normal llama.cpp source tree and causes:
#
#   add_subdirectory given source "examples" which is not an existing directory
#
# llama.cpp examples are controlled separately by LLAMA_BUILD_EXAMPLES.
# -----------------------------------------------------------------------------

COMMON_FLAGS := \
	-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
	-DGGML_NATIVE=ON \
	-DGGML_BUILD_TESTS=OFF \
	-DLLAMA_BUILD_TESTS=OFF \
	-DLLAMA_BUILD_EXAMPLES=OFF \
	-DLLAMA_BUILD_SERVER=ON \
	-DGGML_CCACHE=ON

# -----------------------------------------------------------------------------
# ROCm / HIP
#
# Optimized for gfx1151 / Strix Halo.
#
# GPU_TARGETS:
#   gfx1151
#
# ROCWMMA:
#   Flash Attention acceleration.
#
# NO_VMM:
#   Recommended for current gfx1151 configurations.
#
# MMQ_MFMA:
#   Enables MFMA path where supported.
# -----------------------------------------------------------------------------

ROCM_FLAGS := \
	$(COMMON_FLAGS) \
	-DGGML_HIP=ON \
	-DGGML_HIP_ROCWMMA_FATTN=ON \
	-DGGML_HIP_NO_VMM=ON \
	-DGGML_HIP_MMQ_MFMA=ON \
	-DGGML_VULKAN=OFF \
	-DGGML_CUDA=OFF \
	-DGGML_MUSA=OFF \
	-DGPU_TARGETS=$(GPU_TARGETS)

# -----------------------------------------------------------------------------
# Vulkan
# -----------------------------------------------------------------------------

VULKAN_FLAGS := \
	$(COMMON_FLAGS) \
	-DGGML_VULKAN=ON \
	-DGGML_HIP=OFF \
	-DGGML_CUDA=OFF \
	-DGGML_MUSA=OFF

# =============================================================================
# Default target
# =============================================================================

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo
	@echo "=============================================================="
	@echo " llama.cpp build commands"
	@echo " Ryzen AI Max+ 395 / Radeon 8060S / gfx1151"
	@echo "=============================================================="
	@echo
	@echo "Build:"
	@echo "  make rocm              Build llama-server with ROCm/HIP, then print run command"
	@echo "  make vulkan            Build llama-server with Vulkan, then print run command"
	@echo "  make both              Build ROCm + Vulkan, then print both run commands"
	@echo
	@echo "Configuration:"
	@echo "  make info              Show detected build configuration"
	@echo
	@echo "Clean:"
	@echo "  make clean             Remove all build directories"
	@echo "  make rebuild-rocm      Clean and rebuild ROCm"
	@echo "  make rebuild-vulkan    Clean and rebuild Vulkan"
	@echo "  make rebuild           Clean and rebuild both"
	@echo
	@echo "Verification:"
	@echo "  make verify-rocm       Show ROCm llama-server binary"
	@echo "  make verify-vulkan     Show Vulkan llama-server binary"
	@echo
	@echo "Run commands (printed automatically after a build):"
	@echo "  make show-rocm-command    Print ROCm llama-server run command"
	@echo "  make show-vulkan-command  Print Vulkan llama-server run command"
	@echo
	@echo "Examples:"
	@echo "  make rocm"
	@echo "  make vulkan"
	@echo "  make both JOBS=32"
	@echo "  make rocm BUILD_TYPE=RelWithDebInfo"
	@echo
	@echo "Variables:"
	@echo "  GPU_TARGETS=$(GPU_TARGETS)"
	@echo "  ROCM_PATH=$(ROCM_PATH)"
	@echo "  BUILD_TYPE=$(BUILD_TYPE)"
	@echo "  JOBS=$(JOBS)"
	@echo

# =============================================================================
# Information
# =============================================================================

.PHONY: info
info:
	@echo
	@echo "=============================================================="
	@echo " Build configuration"
	@echo "=============================================================="
	@echo "CPU              : AMD Ryzen AI Max+ 395"
	@echo "GPU              : AMD Radeon 8060S"
	@echo "GPU target       : $(GPU_TARGETS)"
	@echo "Build type       : $(BUILD_TYPE)"
	@echo "Parallel jobs    : $(JOBS)"
	@echo "ROCm path        : $(ROCM_PATH)"
	@echo "HIP_PATH         : $(HIP_PATH)"
	@echo "HIPCXX           : $(HIPCXX)"
	@echo "ROCm build       : $(ROCM_BUILD)"
	@echo "Vulkan build     : $(VULKAN_BUILD)"
	@echo
	@echo "ROCm:"
	@if command -v hipcc >/dev/null 2>&1; then \
		echo "  hipcc          : $$(command -v hipcc)"; \
		hipcc --version | head -n 3; \
	else \
		echo "  hipcc          : NOT FOUND"; \
	fi
	@echo
	@echo "Vulkan:"
	@if command -v vulkaninfo >/dev/null 2>&1; then \
		echo "  vulkaninfo     : found"; \
	else \
		echo "  vulkaninfo     : NOT FOUND"; \
	fi
	@echo

# =============================================================================
# ROCm configuration
# =============================================================================

.PHONY: configure-rocm
configure-rocm:
	@echo
	@echo "=============================================================="
	@echo " Configuring ROCm / HIP"
	@echo "=============================================================="
	@echo " GPU target : $(GPU_TARGETS)"
	@echo " ROCm path  : $(ROCM_PATH)"
	@echo " HIP_PATH   : $(HIP_PATH)"
	@echo " HIPCXX     : $(HIPCXX)"
	@echo "=============================================================="
	@echo

	@if [ -z "$(HIP_PATH)" ]; then \
		echo "ERROR: hipconfig could not determine HIP_PATH."; \
		echo "Check that ROCm is installed and hipconfig is in PATH."; \
		exit 1; \
	fi

	HIPCXX="$(HIPCXX)" \
	HIP_PATH="$(HIP_PATH)" \
	cmake -S . \
		-B "$(ROCM_BUILD)" \
		$(ROCM_FLAGS)

# =============================================================================
# ROCm build
# =============================================================================

.PHONY: rocm
rocm: configure-rocm
	@echo
	@echo "=============================================================="
	@echo " Building llama-server"
	@echo " Backend    : ROCm / HIP"
	@echo " GPU        : $(GPU_TARGETS)"
	@echo "=============================================================="
	@echo

	cmake --build "$(ROCM_BUILD)" \
		--config "$(BUILD_TYPE)" \
		--parallel "$(JOBS)"

	@echo
	@echo "=============================================================="
	@echo " ROCm build complete"
	@echo "=============================================================="
	@find "$(ROCM_BUILD)/bin" -maxdepth 1 -type f -name 'llama-server*' -print 2>/dev/null || true
	@echo
	@$(MAKE) --no-print-directory show-rocm-command

# =============================================================================
# Vulkan configuration
# =============================================================================

.PHONY: configure-vulkan
configure-vulkan:
	@echo
	@echo "=============================================================="
	@echo " Configuring Vulkan"
	@echo "=============================================================="
	@echo

	cmake -S . \
		-B "$(VULKAN_BUILD)" \
		$(VULKAN_FLAGS)

# =============================================================================
# Vulkan build
# =============================================================================

.PHONY: vulkan
vulkan: configure-vulkan
	@echo
	@echo "=============================================================="
	@echo " Building llama-server"
	@echo " Backend    : Vulkan"
	@echo "=============================================================="
	@echo

	cmake --build "$(VULKAN_BUILD)" \
		--config "$(BUILD_TYPE)" \
		--parallel "$(JOBS)"

	@echo
	@echo "=============================================================="
	@echo " Vulkan build complete"
	@echo "=============================================================="
	@find "$(VULKAN_BUILD)/bin" -maxdepth 1 -type f -name 'llama-server*' -print 2>/dev/null || true
	@echo
	@$(MAKE) --no-print-directory show-vulkan-command

# =============================================================================
# Both backends
# =============================================================================
#
# NOTE: rocm and vulkan already print their own run command as their last
# step, so "both" gets both commands for free without duplicating output.
# =============================================================================

.PHONY: both
both: rocm vulkan

# =============================================================================
# ROCm server command
# =============================================================================

.PHONY: show-rocm-command
show-rocm-command:
	@if [ ! -x "$(ROCM_BUILD)/bin/llama-server" ]; then \
		echo; \
		echo "ERROR: llama-server was not found:"; \
		echo "  $(PROJECT_DIR)/$(ROCM_BUILD)/bin/llama-server"; \
		exit 1; \
	fi

	@echo
	@echo "=============================================================="
	@echo " ROCm build complete"
	@echo "=============================================================="
	@echo
	@echo "Run llama-server with:"
	@echo
	@printf 'LD_LIBRARY_PATH="%s/bin" \\\n' "$(PROJECT_DIR)/$(ROCM_BUILD)"
	@printf '"%s/bin/llama-server" \\\n' "$(PROJECT_DIR)/$(ROCM_BUILD)"
	@printf '  -m ~/models/your_model.gguf \\\n'
	@printf '  -a your_model_name \\\n'
	@printf '  -mm ~/models/your_mmproj.gguf --image-min-tokens 1024 \\\n'
	@printf '  --host 0.0.0.0 \\\n'
	@printf '  --port 8888 \\\n'
	@printf '  --jinja \\\n'
	@printf '  -ngl 999 -b 2048 -ub 1024 -t 16 -np 1 \\\n'
	@printf '  -c 262144 \\\n'
	@printf '  --load-mode none \\\n'
	@printf '  -fa on --temp 1.0 --top-k 20 --top-p 0.95 --min-p 0 --presence-penalty 0 --repeat-penalty 1.0 --reasoning on --reasoning-effort xhigh --reasoning-preserve --reasoning-format deepseek \\\n'
	@printf '  -md ~/models/your_mmproj.gguf \\\n'
	@printf '  -ctk q4_0 \\\n'
	@printf '  -ctv q4_0 \\\n'
	@printf '  --spec-type draft-mtp \\\n'
	@printf '  --spec-draft-ngl all --spec-draft-n-max 4 --agent \n'
	@echo
	@echo "=============================================================="
	@echo

# =============================================================================
# Vulkan server command
# =============================================================================

.PHONY: show-vulkan-command
show-vulkan-command:
	@if [ ! -x "$(VULKAN_BUILD)/bin/llama-server" ]; then \
		echo; \
		echo "ERROR: llama-server was not found:"; \
		echo "  $(PROJECT_DIR)/$(VULKAN_BUILD)/bin/llama-server"; \
		exit 1; \
	fi

	@echo
	@echo "=============================================================="
	@echo " Vulkan build complete"
	@echo "=============================================================="
	@echo
	@echo "Run llama-server with:"
	@echo
	@printf 'LD_LIBRARY_PATH="%s/bin" \\\n' "$(PROJECT_DIR)/$(VULKAN_BUILD)"
	@printf '"%s/bin/llama-server" \\\n' "$(PROJECT_DIR)/$(VULKAN_BUILD)"
	@printf '  -m ~/models/your_model.gguf \\\n'
	@printf '  -a your_model_name \\\n'
	@printf '  -mm ~/models/your_mmproj.gguf \\\n'
	@printf '  --host 0.0.0.0 \\\n'
	@printf '  --port 8888 \\\n'
	@printf '  --jinja \\\n'
	@printf '  -ngl 999 -b 2048 -ub 1024 -t 16 -np 1 \\\n'
	@printf '  -c 262144 \\\n'
	@printf '  --load-mode none \\\n'
	@printf '  -fa on --temp 1.0 --top-k 20 --top-p 0.95 --min-p 0 --presence-penalty 0 --repeat-penalty 1.0 --reasoning on --reasoning-effort xhigh --reasoning-preserve --reasoning-format deepseek \\\n'
	@printf '  -md ~/models/your_mmproj.gguf \\\n'
	@printf '  -ctk q4_0 \\\n'
	@printf '  -ctv q4_0 \\\n'
	@printf '  --spec-type draft-mtp \\\n'
	@printf '  --spec-draft-ngl all --spec-draft-n-max 4 --agent \n'
	@echo
	@echo "=============================================================="
	@echo

# =============================================================================
# Verification
# =============================================================================

.PHONY: verify-rocm
verify-rocm:
	@echo "ROCm llama-server:"
	@find "$(ROCM_BUILD)" -type f -name 'llama-server*' -exec file {} \; 2>/dev/null || true

.PHONY: verify-vulkan
verify-vulkan:
	@echo "Vulkan llama-server:"
	@find "$(VULKAN_BUILD)" -type f -name 'llama-server*' -exec file {} \; 2>/dev/null || true

# =============================================================================
# Clean
# =============================================================================

.PHONY: clean
clean:
	rm -rf "$(ROCM_BUILD)" "$(VULKAN_BUILD)"

# =============================================================================
# Rebuild
# =============================================================================

.PHONY: rebuild-rocm
rebuild-rocm:
	rm -rf "$(ROCM_BUILD)"
	$(MAKE) rocm

.PHONY: rebuild-vulkan
rebuild-vulkan:
	rm -rf "$(VULKAN_BUILD)"
	$(MAKE) vulkan

.PHONY: rebuild
rebuild:
	rm -rf "$(ROCM_BUILD)" "$(VULKAN_BUILD)"
	$(MAKE) both
