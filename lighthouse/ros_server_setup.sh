SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &> /dev/null && pwd)
# export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
# export FASTRTPS_DEFAULT_PROFILES_FILE="$SCRIPT_DIR/ros_server_profile.xml"
# echo "set ROS to use profile $FASTRTPS_DEFAULT_PROFILES_FILE"
# conda config --env --add channels conda-forge
# conda config --env --add channels robostack-humble
# conda install ros-humble-rosbridge-server ros-humble-zenoh-bridge-ros2dds 
# pip install zenoh-bridge-dds
# conda activate ros-humble
# wget https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases/download/1.7.2/zenoh-plugin-ros2dds-1.7.2-x86_64-unknown-linux-gnu-standalone.zip
tmux new-session -d -s zenoh_bridge
tmux send-keys -t zenoh_bridge "cd $SCRIPT_DIR && ROS_DISTRO=humble ./zenoh-bridge-ros2dds -c zenoh_server_config.json5" C-m

# cd /home/junzhewu/junzhe/Projects/easy-linux/lighthouse/ && ROS_DISTRO=humble ./zenoh-bridge-ros2dds -c zenoh_server_config.json5
