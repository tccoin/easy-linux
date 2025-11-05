module load singularity
# singularity shell --nv --overlay ~/scratch/overlay.img  \
#   --bind /usr/share/glvnd/egl_vendor.d:/usr/share/glvnd/egl_vendor.d \
#   --bind /etc/glvnd/egl_vendor.d:/etc/glvnd/egl_vendor.d \
#   --env e=egl,__GLX_VENDOR_LIBRARY_NAME=nvidia \
#   ~/scratch/isaac_scenes_v1/sg_vln_isaac3.sif

mkdir -p $HOME/scratch/isaac_cache/omni
mkdir -p $HOME/scratch/isaac_cache/cache_kit
mkdir -p $HOME/scratch/isaac_cache/cache_ov
mkdir -p $HOME/scratch/isaac_cache/cache_pip
mkdir -p $HOME/scratch/isaac_cache/cache_gl
mkdir -p $HOME/scratch/isaac_cache/cache_compute
mkdir -p $HOME/scratch/isaac_cache/logs
mkdir -p $HOME/scratch/isaac_cache/data
mkdir -p $HOME/scratch/isaac_cache/lab_docs
mkdir -p $HOME/scratch/isaac_cache/lab_logs
mkdir -p $HOME/scratch/isaac_cache/lab_data


singularity shell --nv --overlay ~/scratch/overlay1.img \
    --bind $HOME/scratch/isaac_cache/omni:/workspace/conda/envs/vln/lib/python3.10/site-packages/omni/cache/ \
    --bind $HOME/scratch/isaac_cache/cache_kit:/isaac-sim/kit/cache \
    --bind $HOME/scratch/isaac_cache/cache_ov:$HOME/.cache/ov \
    --bind $HOME/scratch/isaac_cache/cache_pip:$HOME/.cache/pip \
    --bind $HOME/scratch/isaac_cache/cache_gl:$HOME/.cache/nvidia/GLCache \
    --bind $HOME/scratch/isaac_cache/cache_compute:$HOME/.nv/ComputeCache \
    --bind $HOME/scratch/isaac_cache/logs:$HOME/.nvidia-omniverse/logs \
    --bind $HOME/scratch/isaac_cache/data:$HOME/.local/share/ov/data \
    --bind $HOME/scratch/isaac_cache/lab_docs:/dependencies/IsaacLab/docs/_build \
    --bind $HOME/scratch/isaac_cache/lab_logs:/dependencies/IsaacLab/logs \
    --bind $HOME/scratch/isaac_cache/lab_data:/dependencies/IsaacLab/data_storage \
    --env ACCEPT_EULA=Y \
    --env GSA_PATH=$HOME/scratch/Grounded-Segment-Anything \
    ~/scratch/isaac_scenes_v1/sg_vln_isaac3.sif
#   --bind /etc/opt/VirtualGL:/etc/opt/VirtualGL \

# VGL_DISPLAY=egl exec ~/vglrun glxinfo | grep "OpenGL renderer"
