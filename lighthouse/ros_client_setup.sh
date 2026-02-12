# ssh -L 0.0.0.0:5001:lh1402.arc-ts.umich.edu:5001 junzhewu@lighthouse.arc-ts.umich.edu
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &> /dev/null && pwd)
# export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
# export FASTRTPS_DEFAULT_PROFILES_FILE="$SCRIPT_DIR/ros_client_profile.xml"
# echo "set ROS to use profile $FASTRTPS_DEFAULT_PROFILES_FILE"

# conda activate tiamat-habitat
# conda activate ros-humble
# export ROS_DISTRO=humble
# cd /root/software-package/easy-linux/lighthouse
# ./zenoh-bridge-ros2dds -e tcp/127.0.0.1:5001
# ros2 topic info /spot/platform/odom --verbose --no-daemon
# ros2 topic info /spot/cmd_vel --verbose --no-daemon
# cd /root/software-package/easy-linux/lighthouse/ && ROS_DISTRO=humble ./zenoh-bridge-ros2dds -c zenoh_client_config.json5

# tmux new-session -d -s zenoh_bridge
# tmux send-keys -t zenoh_bridge "cd $SCRIPT_DIR && ROS_DISTRO=humble ./zenoh-bridge-ros2dds -c zenoh_client_config.json5" C-m

ssh -L 0.0.0.0:5001:lh1402.arc-ts.umich.edu:5001 junzhewu@lighthouse.arc-ts.umich.edu
cd /home/junzhewu/Projects/tiamat/easy-linux/lighthouse && ROS_DISTRO=humble ./zenoh-bridge-ros2dds -c zenoh_client_config.json5