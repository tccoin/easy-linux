module load singularity
cd $HOME/scratch
mkdir -p workspace/upper
mkdir -p workspace/work
mkdir -p dependencies/upper
mkdir -p dependencies/work
if [ ! -f "overlay1.img" ]; then
    echo "Creating overlay1.img"
    dd if=/dev/zero of=overlay1.img bs=1M count=40960 && mkfs.ext3 -d workspace overlay1.img
fi
if [ ! -f "overlay2.img" ]; then
    echo "Creating overlay2.img"
    dd if=/dev/zero of=overlay2.img bs=1M count=40960 && mkfs.ext3 -d workspace overlay2.img
fi
if [ ! -f "overlay3.img" ]; then
    echo "Creating overlay3.img"
    dd if=/dev/zero of=overlay3.img bs=1M count=40960 && mkfs.ext3 -d workspace overlay3.img
fi
if [ ! -f "overlay4.img" ]; then
    echo "Creating overlay4.img"
    dd if=/dev/zero of=overlay4.img bs=1M count=40960 && mkfs.ext3 -d workspace overlay4.img
fi
rm -rf workspace/
rm -rf dependencies/
