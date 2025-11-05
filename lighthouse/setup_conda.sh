# replace /root to /workspace in $PATH and $PYTHONPATH
export PATH=$(echo $PATH | sed 's|/root|/workspace|g')
export PYTHONPATH=$(echo $PYTHONPATH | sed 's|/root|/workspace|g')
# replace /root to /workspace
sed -i "s|/root|/workspace|g" /workspace/conda/bin/conda
sed -i "s|/root|/workspace|g" /workspace/conda/bin/conda-env
sed -i "s|/root|/workspace|g" /workspace/conda/envs/vln/bin/pip
sed -i "s|/root|/workspace|g" /workspace/conda/envs/vln/bin/isaacsim

mkdir -p ~/scratch/.conda
cat > ~/.condarc <<'EOF'
pkgs_dirs:
  - ~/scratch/.conda/pkgs
envs_dirs:
  - ~/scratch/.conda/envs
EOF