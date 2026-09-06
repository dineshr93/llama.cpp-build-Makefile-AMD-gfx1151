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
#   ROCm / HIP (legacy)
#   ROCm 10 (TheRock / core-10.0)
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

ROCM_PATH   ?= /opt/rocm
ROCM10_PATH ?= /opt/rocm/core-10.0

PROJECT_DIR := $(CURDIR)

# -----------------------------------------------------------------------------
# Directories
# -----------------------------------------------------------------------------

ROCM_BUILD   := build-rocm
ROCM10_BUILD := build-rocm10
VULKAN_BUILD := build-vulkan

# -----------------------------------------------------------------------------
# Common flags
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
# ROCm legacy flags
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
	-DGPU_TARGETS=$(GPU_TARGETS) \
	-DAMDGPU_TARGETS=$(GPU_TARGETS)

# -----------------------------------------------------------------------------
# ROCm 10 flags
# -----------------------------------------------------------------------------

ROCM10_FLAGS := \
	$(COMMON_FLAGS) \
	-DGGML_HIP=ON \
	-DGGML_HIP_ROCWMMA_FATTN=ON \
	-DGGML_HIP_NO_VMM=ON \
	-DGGML_HIP_MMQ_MFMA=ON \
	-DGGML_VULKAN=OFF \
	-DGGML_CUDA=OFF \
	-DGGML_MUSA=OFF \
	-DGPU_TARGETS=$(GPU_TARGETS) \
	-DAMDGPU_TARGETS=$(GPU_TARGETS)

# -----------------------------------------------------------------------------
# Vulkan flags
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
	@echo "  make rocm              Build with legacy ROCm/HIP"
	@echo "  make rocm10            Build with ROCm 10 (core-10.0)  ← recommended"
	@echo "  make vulkan            Build with Vulkan"
	@echo "  make both              Build ROCm + Vulkan"
	@echo
	@echo "Configuration:"
	@echo "  make info              Show detected build configuration"
	@echo
	@echo "Clean / Rebuild:"
	@echo "  make clean             Remove all build directories"
	@echo "  make rebuild-rocm      Clean + rebuild legacy ROCm"
	@echo "  make rebuild-rocm10    Clean + rebuild ROCm 10"
	@echo "  make rebuild-vulkan    Clean + rebuild Vulkan"
	@echo "  make rebuild           Clean + rebuild everything"
	@echo
	@echo "Verification:"
	@echo "  make verify-rocm"
	@echo "  make verify-rocm10"
	@echo "  make verify-vulkan"
	@echo
	@echo "Run commands:"
	@echo "  make show-rocm-command"
	@echo "  make show-rocm10-command"
	@echo "  make show-vulkan-command"
	@echo
	@echo "Examples:"
	@echo "  make rocm10"
	@echo "  make vulkan"
	@echo "  make both JOBS=32"
	@echo
	@echo "Variables:"
	@echo "  GPU_TARGETS=$(GPU_TARGETS)"
	@echo "  ROCM_PATH=$(ROCM_PATH)"
	@echo "  ROCM10_PATH=$(ROCM10_PATH)"
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
	@echo "ROCm 10 path     : $(ROCM10_PATH)"
	@echo "ROCm build       : $(ROCM_BUILD)"
	@echo "ROCm 10 build    : $(ROCM10_BUILD)"
	@echo "Vulkan build     : $(VULKAN_BUILD)"
	@echo
	@echo "ROCm 10:"
	@if [ -x "$(ROCM10_PATH)/bin/rocminfo" ]; then \
		echo "  rocminfo       : found"; \
		$(ROCM10_PATH)/bin/rocminfo | grep -E 'Name:.*gfx' | head -3; \
	else \
		echo "  rocminfo       : NOT FOUND"; \
	fi
	@if [ -x "$(ROCM10_PATH)/bin/amdclang" ]; then \
		echo "  amdclang       : $(ROCM10_PATH)/bin/amdclang"; \
	else \
		echo "  amdclang       : NOT FOUND"; \
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
# ROCm (legacy)
# =============================================================================

.PHONY: configure-rocm
configure-rocm:
	@echo
	@echo "=============================================================="
	@echo " Configuring ROCm / HIP (classic-style target)"
	@echo "=============================================================="
	@echo " Note: system only has ROCm 10 → using $(ROCM10_PATH)"
	@echo

	@if [ ! -x "$(ROCM10_PATH)/bin/amdclang" ]; then \
		echo "ERROR: amdclang not found in $(ROCM10_PATH)/bin"; \
		exit 1; \
	fi

	HIP_PATH="$(ROCM10_PATH)" \
	ROCM_PATH="$(ROCM10_PATH)" \
	cmake -S . \
		-B "$(ROCM_BUILD)" \
		$(ROCM_FLAGS) \
		-DCMAKE_PREFIX_PATH="$(ROCM10_PATH)" \
		-DCMAKE_HIP_COMPILER="$(ROCM10_PATH)/bin/amdclang" \
		-DCMAKE_C_COMPILER="$(ROCM10_PATH)/bin/amdclang" \
		-DCMAKE_CXX_COMPILER="$(ROCM10_PATH)/bin/amdclang++"

.PHONY: rocm
rocm: configure-rocm
	@echo
	@echo "=============================================================="
	@echo " Building llama-server (legacy ROCm)"
	@echo "=============================================================="
	@echo

	cmake --build "$(ROCM_BUILD)" \
		--config "$(BUILD_TYPE)" \
		--parallel "$(JOBS)"

	@echo
	@echo "Legacy ROCm build complete"
	@find "$(ROCM_BUILD)/bin" -maxdepth 1 -type f -name 'llama-server*' -print 2>/dev/null || true
	@$(MAKE) --no-print-directory show-rocm-command

# =============================================================================
# ROCm 10
# =============================================================================

.PHONY: configure-rocm10
configure-rocm10:
	@echo
	@echo "=============================================================="
	@echo " Configuring ROCm 10 / HIP"
	@echo "=============================================================="
	@echo " GPU target : $(GPU_TARGETS)"
	@echo " ROCm path  : $(ROCM10_PATH)"
	@echo "=============================================================="
	@echo

	@if [ ! -d "$(ROCM10_PATH)" ]; then \
		echo "ERROR: ROCm 10 path not found: $(ROCM10_PATH)"; \
		exit 1; \
	fi
	@if [ ! -x "$(ROCM10_PATH)/bin/amdclang" ]; then \
		echo "ERROR: amdclang not found in $(ROCM10_PATH)/bin"; \
		exit 1; \
	fi

	# Important: do NOT set HIPCXX
	HIP_PATH="$(ROCM10_PATH)" \
	ROCM_PATH="$(ROCM10_PATH)" \
	cmake -S . \
		-B "$(ROCM10_BUILD)" \
		$(ROCM10_FLAGS) \
		-DCMAKE_PREFIX_PATH="$(ROCM10_PATH)" \
		-DCMAKE_HIP_COMPILER="$(ROCM10_PATH)/bin/amdclang" \
		-DCMAKE_C_COMPILER="$(ROCM10_PATH)/bin/amdclang" \
		-DCMAKE_CXX_COMPILER="$(ROCM10_PATH)/bin/amdclang++"

.PHONY: rocm10
rocm10: configure-rocm10
	@echo
	@echo "=============================================================="
	@echo " Building llama-server (ROCm 10)"
	@echo "=============================================================="
	@echo

	cmake --build "$(ROCM10_BUILD)" \
		--config "$(BUILD_TYPE)" \
		--parallel "$(JOBS)"

	@echo
	@echo "ROCm 10 build complete"
	@find "$(ROCM10_BUILD)/bin" -maxdepth 1 -type f -name 'llama-server*' -print 2>/dev/null || true
	@$(MAKE) --no-print-directory show-rocm10-command

# =============================================================================
# Vulkan
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

.PHONY: vulkan
vulkan: configure-vulkan
	@echo
	@echo "=============================================================="
	@echo " Building llama-server (Vulkan)"
	@echo "=============================================================="
	@echo

	cmake --build "$(VULKAN_BUILD)" \
		--config "$(BUILD_TYPE)" \
		--parallel "$(JOBS)"

	@echo
	@echo "Vulkan build complete"
	@find "$(VULKAN_BUILD)/bin" -maxdepth 1 -type f -name 'llama-server*' -print 2>/dev/null || true
	@$(MAKE) --no-print-directory show-vulkan-command

# =============================================================================
# Both
# =============================================================================

.PHONY: both
both: rocm vulkan

# =============================================================================
# Run commands
# =============================================================================

.PHONY: show-rocm-command
show-rocm-command:
	@echo
	@echo "Run (legacy ROCm):"
	@echo
	@printf 'LD_LIBRARY_PATH="%s/bin" \\\n' "$(PROJECT_DIR)/$(ROCM_BUILD)"
	@printf '"%s/bin/llama-server" \\\n' "$(PROJECT_DIR)/$(ROCM_BUILD)"
	@printf '  -m ~/models/your_model.gguf \\\n'
	@printf '  -a your_model \\\n'
	@printf '  -mm ~/models/mmproj-BF32.gguf --image-min-tokens 1024 \\\n'
	@printf '  --host 0.0.0.0 \\\n'
	@printf '  --port 8888 \\\n'
	@printf '  -c 162144 --jinja -ngl 999 \\\n'
	@printf '  --spec-type draft-mtp --spec-draft-n-max 4 --spec-draft-ngl all \\\n'
	@printf '  -b 2048 -ub 1024 -t 16 -np 1 \\\n'
	@printf '  --load-mode none -fa on \\\n'
	@printf '  --temp 1.0 --top-k 20 --top-p 0.85 --min-p 0 \\\n'
	@printf '  --presence-penalty 0 --repeat-penalty 1.0 \\\n'
	@printf '  --reasoning on --reasoning-effort xhigh --reasoning-preserve --reasoning-format deepseek\n'
	@echo
	@printf 'LD_LIBRARY_PATH="%s/bin" \\\n' "$(PROJECT_DIR)/$(ROCM_BUILD)"
	@printf '"%s/bin/llama-bench" \\\n' "$(PROJECT_DIR)/$(ROCM_BUILD)"
	@printf '  -m ~/models/your_model.gguf \\\n'
	@printf '  -p 4096 -n 128 -b 2048 -ub 2048 -ngl 999 -fa on -r 3 -o json\n'
	@echo

.PHONY: show-rocm10-command
show-rocm10-command:
	@echo
	@echo "Run (ROCm 10):"
	@echo
	@printf 'LD_LIBRARY_PATH="%s/lib:%s/bin" \\\n' "$(ROCM10_PATH)" "$(PROJECT_DIR)/$(ROCM10_BUILD)"
	@printf 'ROCBLAS_USE_HIPBLASLT=1 \\\n'
	@printf '"%s/bin/llama-server" \\\n' "$(PROJECT_DIR)/$(ROCM10_BUILD)"
	@printf '  -m ~/models/your_model.gguf \\\n'
	@printf '  -a your_model \\\n'
	@printf '  -mm ~/models/mmproj-BF32.gguf --image-min-tokens 1024 \\\n'
	@printf '  --host 0.0.0.0 \\\n'
	@printf '  --port 8888 \\\n'
	@printf '  -c 162144 --jinja -ngl 999 \\\n'
	@printf '  --spec-type draft-mtp --spec-draft-n-max 4 --spec-draft-ngl all \\\n'
	@printf '  -b 2048 -ub 1024 -t 16 -np 1 \\\n'
	@printf '  --load-mode none -fa on \\\n'
	@printf '  --temp 1.0 --top-k 20 --top-p 0.85 --min-p 0 \\\n'
	@printf '  --presence-penalty 0 --repeat-penalty 1.0 \\\n'
	@printf '  --reasoning on --reasoning-effort xhigh --reasoning-preserve --reasoning-format deepseek\n'
	@echo
	@printf 'LD_LIBRARY_PATH="%s/lib:%s/bin" \\\n' "$(ROCM10_PATH)" "$(PROJECT_DIR)/$(ROCM10_BUILD)"
	@printf 'ROCBLAS_USE_HIPBLASLT=1 \\\n'
	@printf '"%s/bin/llama-bench" \\\n' "$(PROJECT_DIR)/$(ROCM10_BUILD)"
	@printf '  -m ~/models/your_model.gguf \\\n'
	@printf '  -p 4096 -n 128 -b 2048 -ub 2048 -ngl 999 -fa on -r 3 -o json\n'
	@echo

.PHONY: show-vulkan-command
show-vulkan-command:
	@echo
	@echo "Run (Vulkan):"
	@echo
	@printf 'LD_LIBRARY_PATH="%s/bin" \\\n' "$(PROJECT_DIR)/$(VULKAN_BUILD)"
	@printf '"%s/bin/llama-server" \\\n' "$(PROJECT_DIR)/$(VULKAN_BUILD)"
	@printf '  -m ~/models/your_model.gguf \\\n'
	@printf '  -a your_model \\\n'
	@printf '  -mm ~/models/mmproj-BF32.gguf --image-min-tokens 1024 \\\n'
	@printf '  --host 0.0.0.0 \\\n'
	@printf '  --port 8888 \\\n'
	@printf '  -c 162144 --jinja -ngl 999 \\\n'
	@printf '  --spec-type draft-mtp --spec-draft-n-max 4 --spec-draft-ngl all \\\n'
	@printf '  -b 2048 -ub 1024 -t 16 -np 1 \\\n'
	@printf '  --load-mode none -fa on \\\n'
	@printf '  --temp 1.0 --top-k 20 --top-p 0.85 --min-p 0 \\\n'
	@printf '  --presence-penalty 0 --repeat-penalty 1.0 \\\n'
	@printf '  --reasoning on --reasoning-effort xhigh --reasoning-preserve --reasoning-format deepseek\n'
	@echo
	@printf 'LD_LIBRARY_PATH="%s/bin" \\\n' "$(PROJECT_DIR)/$(VULKAN_BUILD)"
	@printf '"%s/bin/llama-bench" \\\n' "$(PROJECT_DIR)/$(VULKAN_BUILD)"
	@printf '  -m ~/models/your_model.gguf \\\n'
	@printf '  -p 4096 -n 128 -b 2048 -ub 2048 -ngl 999 -fa on -r 3 -o json\n'
	@echo

# =============================================================================
# Verification
# =============================================================================

.PHONY: verify-rocm
verify-rocm:
	@echo "Legacy ROCm llama-server:"
	@find "$(ROCM_BUILD)" -type f -name 'llama-server*' -exec file {} \; 2>/dev/null || true

.PHONY: verify-rocm10
verify-rocm10:
	@echo "ROCm 10 llama-server:"
	@find "$(ROCM10_BUILD)" -type f -name 'llama-server*' -exec file {} \; 2>/dev/null || true

.PHONY: verify-vulkan
verify-vulkan:
	@echo "Vulkan llama-server:"
	@find "$(VULKAN_BUILD)" -type f -name 'llama-server*' -exec file {} \; 2>/dev/null || true

# =============================================================================
# Clean / Rebuild
# =============================================================================

.PHONY: clean
clean:
	rm -rf "$(ROCM_BUILD)" "$(ROCM10_BUILD)" "$(VULKAN_BUILD)"

.PHONY: rebuild-rocm
rebuild-rocm:
	rm -rf "$(ROCM_BUILD)"
	$(MAKE) rocm

.PHONY: rebuild-rocm10
rebuild-rocm10:
	rm -rf "$(ROCM10_BUILD)"
	$(MAKE) rocm10

.PHONY: rebuild-vulkan
rebuild-vulkan:
	rm -rf "$(VULKAN_BUILD)"
	$(MAKE) vulkan

.PHONY: rebuild
rebuild:
	rm -rf "$(ROCM_BUILD)" "$(ROCM10_BUILD)" "$(VULKAN_BUILD)"
	$(MAKE) both
