SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &> /dev/null && pwd)
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export FASTRTPS_DEFAULT_PROFILES_FILE="$SCRIPT_DIR/ros_client_profile.xml"
echo "set ROS to use profile $FASTRTPS_DEFAULT_PROFILES_FILE"