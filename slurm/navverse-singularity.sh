#!/usr/bin/env bash
# Optimized Singularity launcher with auto-job detection
set -e

# --- Colors for better UI ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- 1. Configuration Defaults ---
SIF_PATH="${SIF_PATH:-/home/junzhewu/turbo-coe-junzhewu/navverse_mar25.sif}"
OVERLAY_IMG="$HOME/turbo-coe-junzhewu/overlays/navverse.img"
CONTAINER_HOME="/workspace"
CONTAINER_LIB_PATH="/usr/lib/x86_64-linux-gnu"
CACHE_DIR="$HOME/turbo-coe-junzhewu/isaac_sim_cache"

# --- 2. Auto-Detect Running Job ID ---
TARGET_JOB=""
if [[ -n "${1:-}" && "$1" =~ ^[0-9]+$ ]]; then
    TARGET_JOB="$1"
else
    RUNNING_JOBS=($(squeue -u "$USER" -t R -h -o %A))
    if [ ${#RUNNING_JOBS[@]} -eq 1 ]; then
        TARGET_JOB="${RUNNING_JOBS[0]}"
        echo -e "${BLUE}--> Auto-detected running Job ID:${NC} ${GREEN}$TARGET_JOB${NC}"
    elif [ ${#RUNNING_JOBS[@]} -gt 1 ]; then
        echo -e "${YELLOW}--> Multiple jobs running: ${RUNNING_JOBS[*]}. Please specify one.${NC}"
        exit 1
    fi
fi

# --- 3. Resource & Bind Preparation ---
[[ -f "$SIF_PATH" ]] || { echo -e "${YELLOW}ERROR: SIF not found at $SIF_PATH${NC}"; exit 1; }

TMP_DIR="/dev/shm/singularity-tmp"

BIND_ARGS=(
    --bind "$HOME/Projects:$CONTAINER_HOME/Projects"
    --bind "$HOME/turbo-coe-junzhewu:$CONTAINER_HOME/turbo-coe-junzhewu"
    --bind "$HOME/scratch:$CONTAINER_HOME/scratch"
    --bind "$HOME/tasks:$CONTAINER_HOME/tasks"
    --bind "$HOME/.zshrc:$CONTAINER_HOME/.zshrc"
    --bind "$HOME/.zsh_history:$CONTAINER_HOME/.zsh_history"
    --bind "$HOME/.oh-my-zsh:$CONTAINER_HOME/.oh-my-zsh"
    --bind "$HOME/.p10k.zsh:$CONTAINER_HOME/.p10k.zsh"
    --bind "$HOME/.config:$CONTAINER_HOME/.config"
    --bind "$HOME/.claude:$CONTAINER_HOME/.claude"
    --bind "$HOME/.vnc:$CONTAINER_HOME/.vnc"
    --bind "$HOME/.Xauthority:$CONTAINER_HOME/.Xauthority"
    --bind "$CACHE_DIR/kit:$CONTAINER_HOME/conda/envs/navverse/lib/python3.11/site-packages/isaacsim/kit/cache"
    --bind "$CACHE_DIR/ov:$CONTAINER_HOME/.cache/ov"
    --bind "$CACHE_DIR/pip:$CONTAINER_HOME/.cache/pip"
    --bind "$CACHE_DIR/gl:$CONTAINER_HOME/.cache/nvidia/GLCache"
    --bind "$CACHE_DIR/cache_compute:$CONTAINER_HOME/.nv/ComputeCache"
    --bind "$CACHE_DIR/logs:$CONTAINER_HOME/.nvidia-omniverse/logs"
    --bind "$CACHE_DIR/carb_logs:$CONTAINER_HOME/conda/envs/navverse/lib/python3.11/site-packages/isaacsim/kit/logs/Kit/Isaac-Sim"
    --bind "$CACHE_DIR/data:$CONTAINER_HOME/.local/share/ov/data"
    --bind "$TMP_DIR:/tmp"
    --bind "/sw:/sw"
    --bind /tmp/.X11-unix:/tmp/.X11-unix
    --bind /usr/share/vulkan/icd.d:/usr/share/vulkan/icd.d
    --bind /etc/vulkan/:/etc/vulkan/
    --bind /dev/shm:/shm
)

# Flatten bind arguments into a safely quoted string
BIND_STR=""
for arg in "${BIND_ARGS[@]}"; do BIND_STR+="$(printf " %q" "$arg")"; done

[[ -f "$OVERLAY_IMG" ]] && OVERLAY_CMD="--overlay $OVERLAY_IMG" || OVERLAY_CMD=""

# --- 4. Execution ---

# We define the inner shell command that overrides HOME *after* entering the container
# 1. Export HOME and ZDOTDIR inside the container's initial bash
# 2. Change directory to /workspace
# 3. Execute zsh
INNER_SHELL_CMD="
  export HOME=$CONTAINER_HOME;
  export ZDOTDIR=$CONTAINER_HOME;
  export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json;
  # mkdir -p /tmp/vulkan_libs
  # ln -sf /usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.590.48.01 /usr/lib64/libGLX_nvidia.so.0
  cd $CONTAINER_HOME && exec zsh -l"
if [[ -z "$TARGET_JOB" ]]; then
    echo -e "${BLUE}--- Starting Local Container ---${NC}"
    # Local: We still need to find libs on the current node
    DYN_BINDS=()
    for lib in /usr/lib64/libnvidia-* /usr/lib64/libcuda.so* /usr/lib64/libGLX_nvidia.so*; do
        [ -e "$lib" ] && DYN_BINDS+=(--bind "${lib}:${CONTAINER_LIB_PATH}/$(basename "$lib")")
    done
    GLX_DRIVER_LIB="$(readlink -f /usr/lib64/libGLX_nvidia.so.0 2>/dev/null || true)"
    if [[ -z "$GLX_DRIVER_LIB" || ! -e "$GLX_DRIVER_LIB" ]]; then
        for candidate in /usr/lib64/libGLX_nvidia.so.*; do
            [[ -e "$candidate" && "$candidate" != *.so.0 ]] || continue
            GLX_DRIVER_LIB="$candidate"
            break
        done
    fi
    [[ -n "$GLX_DRIVER_LIB" ]] && DYN_BINDS+=(--bind "${GLX_DRIVER_LIB}:/usr/lib64/libGLX_nvidia.so.0")
    exec singularity exec --nv  $OVERLAY_CMD "${BIND_ARGS[@]}" "${DYN_BINDS[@]}" "$SIF_PATH" bash -c "$INNER_SHELL_CMD"
else
    echo -e "${BLUE}--- Connecting to Remote Job:${NC} ${GREEN}$TARGET_JOB${NC} ${BLUE}---${NC}"
    
    # Construct a robust REMOTE_CMD that:
    # 1. Scans for NVIDIA libs ON THE COMPUTE NODE
    # 2. Inherits host environment (since we removed --cleanenv)
    # 3. Executes singularity
REMOTE_CMD="
    module load singularity >/dev/null 2>&1;
    
    # Create an array for dynamic NVIDIA binds
    DYN_BINDS=();
    
    # Search for NVIDIA libraries on the HOST (Compute Node)
    # We check /usr/lib64 first (Great Lakes standard)
    HOST_LIB_SRC='/usr/lib64'
    if [ ! -d \"\$HOST_LIB_SRC\" ]; then HOST_LIB_SRC='${CONTAINER_LIB_PATH}'; fi
    
    for lib in \$HOST_LIB_SRC/libnvidia-* \$HOST_LIB_SRC/libcuda.so* \$HOST_LIB_SRC/libGLX_nvidia.so*; do
        if [ -e \"\$lib\" ]; then
            filename=\$(basename \"\$lib\")
            # Key: Bind Host file -> Container path
            DYN_BINDS+=(--bind \"\$lib:${CONTAINER_LIB_PATH}/\$filename\")
        fi
    done;
    GLX_DRIVER_LIB=\$(readlink -f \"\$HOST_LIB_SRC/libGLX_nvidia.so.0\" 2>/dev/null || true);
    if [[ -z \"\$GLX_DRIVER_LIB\" || ! -e \"\$GLX_DRIVER_LIB\" ]]; then
        for candidate in \$HOST_LIB_SRC/libGLX_nvidia.so.*; do
            [[ -e \"\$candidate\" && \"\$candidate\" != *.so.0 ]] || continue
            GLX_DRIVER_LIB=\"\$candidate\"
            break
        done
    fi
    if [[ -n \"\$GLX_DRIVER_LIB\" ]]; then
        DYN_BINDS+=(--bind \"\$GLX_DRIVER_LIB:/usr/lib64/libGLX_nvidia.so.0\")
    fi

    echo \"--> Bound \${#DYN_BINDS[@]} NVIDIA libraries to ${CONTAINER_LIB_PATH}\";

    mkdir -p $TMP_DIR

    if [ ! -f \"$TMP_DIR/navverse.sif\" ]; then
        pv \"$SIF_PATH\" > $TMP_DIR/navverse.sif
    fi

    if [ ! -f \"$TMP_DIR/navverse.img\" ]; then
        pv \"$OVERLAY_IMG\" > $TMP_DIR/navverse.img
    fi

    # Execute Singularity WITHOUT --cleanenv to ensure environment flows through
    exec singularity exec --nv --containall --overlay $TMP_DIR/navverse.img $BIND_STR \"\${DYN_BINDS[@]}\" $(printf " %q" "$TMP_DIR/navverse.sif") bash -c $(printf "%q" "$INNER_SHELL_CMD")
"

    # CRITICAL: We add DISPLAY to --export to ensure X11 works over srun
    exec srun --jobid "$TARGET_JOB" --export=ALL,SIF_PATH,DISPLAY --overlap --pty bash -lc "$REMOTE_CMD"
fi