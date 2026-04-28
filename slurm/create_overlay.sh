OVERLAY_NAME="navverse"
OVERLAY_DIR="$HOME/turbo-coe-junzhewu/overlays/"
mkdir -p $OVERLAY_DIR
cd $HOME/turbo-coe-junzhewu/overlays/
echo "Creating overlay $OVERLAY_NAME.img..."
truncate -s 40G $OVERLAY_NAME.img
mkfs.ext3 $OVERLAY_NAME.img
debugfs -w -R "mkdir upper" $OVERLAY_NAME.img
debugfs -w -R "mkdir work" $OVERLAY_NAME.img