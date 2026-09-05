# llama.cpp build Makefile — AMD Ryzen AI Max+ 395 / Radeon 8060S (gfx1151)

A wrapper Makefile that configures, builds, and verifies `llama-server` from
[`ggml-org/llama.cpp`](https://github.com/ggml-org/llama.cpp) (or any fork based
on current upstream) on an AMD **Strix Halo** system: the Ryzen AI Max+ 395 CPU
and Radeon 8060S integrated GPU with the `gfx1151` target.

It supports both ROCm/HIP and Vulkan backends. The most useful behaviour is that
**after a successful build it automatically prints the actual run command** for
you to copy and adapt.

---

## Quick start

```sh
make rocm        # build llama-server with ROCm/HIP, then print the run command
make vulkan      # build llama-server with Vulkan,      then print the run command
make both        # build both backends,                 then print both commands
make info        # show the detected build configuration (no build)
```

Run `make` with **no arguments** to see the full list of available commands.

---

## What the Makefile does

1. **Configure** — runs `cmake` with a set of backend-specific flags into a
   dedicated build directory (`build-rocm` or `build-vulkan`).
2. **Build** — runs `cmake --build` with `-j$(JOBS)` parallelism.
3. **Verify & print** — finds `llama-server` in the build `bin/` directory and
   prints a copy-and-adapt run command.

The build directories are **separate per backend**, so ROCm and Vulkan builds
never interfere with each other.

---

## Backends

### ROCm 10 (`make rocm10`)

```sh
# install https://rocm.docs.amd.com/en/latest/install/rocm.html?fam=ryzen&w=graphics&os=ubuntu&ubuntu-ver=26.04&i=amdgpu-install
sudo apt install amdrocm-runtime-dev10.0
sudo apt install amdrocm-blas-dev10.0
sudo apt install amdrocm-hipblas-common-dev10.0
```

### ROCm / HIP (`make rocm`)

Optimized for gfx1151 / Strix Halo. Key CMake flags (see the `ROCM_FLAGS`
variable in the Makefile):

| Flag | Purpose |
|------|---------|
| `GGML_HIP=ON` | Enable the HIP/ROCm backend |
| `GGML_HIP_ROCWMMA_FATTN=ON` | Flash Attention acceleration |
| `GGML_HIP_NO_VMM=ON` | Recommended for current gfx1151 configs |
| `GGML_HIP_MMQ_MFMA=ON` | Enable the MFMA path where supported |
| `GPU_TARGETS=gfx1151` | Compile for the Strix Halo GPU |

ROCm/HIP requires the ROCm toolkit installed; `hipconfig` must be on `PATH`.
The Makefile auto-detects `HIP_PATH` and the clang compiler via `hipcc`.

### Vulkan (`make vulkan`)

A portable alternative that needs no ROCm install — just a Vulkan driver:

| Flag | Purpose |
|------|---------|
| `GGML_VULKAN=ON` | Enable the Vulkan backend |
| `GGML_HIP=OFF`, `GGML_CUDA=OFF`, `GGML_MUSA=OFF` | Disable competing backends |

---

## Common configuration (both backends)

`COMMON_FLAGS` applies to every build:

| Flag | Purpose |
|------|---------|
| `GGML_NATIVE=ON` | Use native CPU instructions |
| `GGML_BUILD_TESTS=OFF` / `LLAMA_BUILD_TESTS=OFF` | Skip test targets |
| `LLAMA_BUILD_EXAMPLES=OFF` | Only build what the server needs |
| `LLAMA_BUILD_SERVER=ON` | Build `llama-server` |
| `GGML_CCACHE=ON` | Speed up rebuilds with ccache |

> **Do NOT set `GGML_BUILD_EXAMPLES=ON`.** `ggml/examples` does not exist in
> the normal llama.cpp tree and breaks the configure step. llama.cpp examples
> are controlled separately by `LLAMA_BUILD_EXAMPLES`.

---

## Configuration variables

Override these on the `make` command line as needed:

| Variable | Default | Meaning |
|----------|---------|---------|
| `GPU_TARGETS` | `gfx1151` | AMD GPU target(s) to compile for |
| `BUILD_TYPE` | `Release` | CMake build type (e.g. `RelWithDebInfo`) |
| `JOBS` | `nproc` | Parallel build jobs |
| `ROCM_PATH` | `/opt/rocm` | ROCm install path |

Examples:

```sh
make rocm BUILD_TYPE=RelWithDebInfo
make both JOBS=32 GPU_TARGETS="gfx1151 gfx1100"
```

---

## Run commands

After a build, the Makefile prints a ready-to-copy `llama-server` invocation.
The exact command is printed automatically as the last step of each build
target, or on demand:

```sh
make show-rocm-command
make show-vulkan-command
```

The printed command uses **placeholder values you must adapt** — model paths,
names, and port. For example (ROCm):

```sh
LD_LIBRARY_PATH="/path/to/build-rocm/bin" \
"/path/to/build-rocm/bin/llama-server" \
  -m ~/models/your_model.gguf \
  -a your_model_name \
  -mm ~/models/your_mmproj.gguf \
  --host 0.0.0.0 \
  --port 8888 \
  --jinja \
  -ngl 99 \
  -c 262144 \
  --load-mode none \
  -fa on \
  -md ~/models/your_mmproj.gguf \
  -ctk q4_0 \
  -ctv q4_0 \
  --spec-type draft-drafttype \
  --spec-draft-ngl all
```

Replace `~/models/your_model.gguf` and `~/models/your_mmproj.gguf` with your
real model and multimodal-projection files, change `your_model_name`, and set
`--port` / host as you like. `LD_LIBRARY_PATH` must point at the build's `bin/`
so the server finds its ROCm/HIP runtime libraries.

---

## Clean & rebuild

| Command | Effect |
|---------|--------|
| `make clean` | Remove both `build-rocm` and `build-vulkan` |
| `make rebuild-rocm` | Delete `build-rocm`, then rebuild ROCm |
| `make rebuild-vulkan` | Delete `build-vulkan`, then rebuild Vulkan |
| `make rebuild` | Delete both build dirs, then rebuild both |

---

## Verification

```sh
make verify-rocm    # find and file-type the ROCm llama-server binary
make verify-vulkan  # find and file-type the Vulkan llama-server binary
```

---

## Layout

| Path | Purpose |
|------|---------|
| `build-rocm/` | ROCm/HIP build output (contains `bin/llama-server`) |
| `build-vulkan/` | Vulkan build output (contains `bin/llama-server`) |
| `Makefile` | The build wrapper itself |

The Makefile is a thin driver around `cmake`; the actual llama.cpp sources live
at the project root of this repo.
