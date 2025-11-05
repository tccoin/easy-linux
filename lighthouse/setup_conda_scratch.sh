__conda_setup="$('/home/junzhewu/scratch/miniconda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/junzhewu/scratch/miniconda/etc/profile.d/conda.sh" ]; then
        . "/home/junzhewu/scratch/miniconda/etc/profile.d/conda.sh"
    else
        export PATH="/home/junzhewu/scratch/miniconda/bin:$PATH"
    fi
fi
unset __conda_setup