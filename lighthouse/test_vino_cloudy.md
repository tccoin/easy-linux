# on cloudy
fastdds discovery -i 0 -l 141.212.194.241 -p 11811


docker run --name tiamat --entrypoint bash -it --gpus all \
--network=host \
--runtime=nvidia \
-e X11_FORWARDING_ENABLED=1 \
-e PRIVACY_CONSENT=Y \
-e ACCEPT_EULA=Y \
-e DISPLAY=$DISPLAY \
-e XAUTHORITY=/root/.Xauthority \
-v /tmp/.X11-unix:/tmp/.X11-unix \
-v ~/.Xauthority:/root/.Xauthority:rw \
-v ~/docker/isaac-sim/cache/kit:/isaac-sim/kit/cache:rw \
-v ~/docker/isaac-sim/cache/ov:/root/.cache/ov:rw \
-v ~/docker/isaac-sim/cache/pip:/root/.cache/pip:rw \
-v ~/docker/isaac-sim/cache/glcache:/root/.cache/nvidia/GLCache:rw \
-v ~/docker/isaac-sim/cache/computecache:/root/.nv/ComputeCache:rw \
-v ~/docker/isaac-sim/logs:/root/.nvidia-omniverse/logs:rw \
-v ~/docker/isaac-sim/data:/root/.local/share/ov/data:rw \
-v ~/docker/isaac-sim/documents:/root/Documents:rw \
276226212704.dkr.ecr.us-gov-west-1.amazonaws.com/tiamat/baseline:latest

export ROS_DISCOVERY_SERVER="141.212.194.241:11811"
echo "export ROS_DISCOVERY_SERVER=141.212.194.241:11811" >> ~/.bashrc
conda activate tiamat-habitat
bash run_eval.sh --rr

export ROS_DISCOVERY_SERVER="141.212.194.241:11811"
ros2 topic list --no-daemon

conda activate tiamat-habitat
export ROS_DISCOVERY_SERVER="141.212.194.241:11811"
python -O /root/habitat_environment/sim/tiamat_runner.py --final

python3 -c "import os; print(os.environ.get('ROS_DISCOVERY_SERVER'))"

ros2 run demo_nodes_cpp talker
ros2 run demo_nodes_cpp listener

export FASTRTPS_DEFAULT_PROFILES_FILE=/root/discovery_conf.xml
python -O /root/habitat_environment/sim/tiamat_runner.py --final

conda install -y -c robostack ros-galactic-ros2cli ros-galactic-ros2node ros-galactic-ros2topic ros-galactic-ros2run ros-galactic-ros2launch ros-galactic-ros2service ros-galactic-ros2param ros-galactic-demo-nodes-cpp ros-galactic-demo-nodes-py


# 1. Kill the host's background daemon
ros2 daemon stop

# 2. Point to the new compatibility profile
export FASTRTPS_DEFAULT_PROFILES_FILE=~/humble_super_client.xml
export ROS_DISCOVERY_SERVER="141.212.194.241:11811"

# 3. Try to listen (The --no-daemon flag is vital here)
ros2 run demo_nodes_cpp listener --ros-args --remap __node:=host_listener


conda install -c robostack zenoh-bridge-ros2python


wget https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases/download/1.7.2/zenoh-plugin-ros2dds-1.7.2-x86_64-unknown-linux-gnu-standalone.zip
extract zenoh-plugin-ros2dds-1.7.2-x86_64-unknown-linux-gnu-standalone.zip
cd zenoh-plugin-ros2dds-1.7.2-x86_64-unknown-linux-gnu-standalone
./zenoh-bridge-ros2dds -e tcp/141.212.194.241:7447

git clone https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds.git
cd zenoh-plugin-ros2dds
cargo build --release -p zenoh-bridge-ros2dds
# isaac sim
conda activate tiamat-isaac
export DISPLAY=:2
phx-sim --scene camping --task risk-reduction

# FINAL COMMANDS

on cloudy:

ROS_DISTRO=humble ~/Projects/tiamat/easy-linux/lighthouse/zenoh-bridge-ros2dds

docker run --name tiamat --entrypoint bash -it --gpus all \
--network=host \
--runtime=nvidia \
-e X11_FORWARDING_ENABLED=1 \
-e PRIVACY_CONSENT=Y \
-e ACCEPT_EULA=Y \
-e DISPLAY=$DISPLAY \
-e XAUTHORITY=/root/.Xauthority \
-v /tmp/.X11-unix:/tmp/.X11-unix \
-v ~/.Xauthority:/root/.Xauthority:rw \
-v ~/docker/isaac-sim/cache/kit:/isaac-sim/kit/cache:rw \
-v ~/docker/isaac-sim/cache/ov:/root/.cache/ov:rw \
-v ~/docker/isaac-sim/cache/pip:/root/.cache/pip:rw \
-v ~/docker/isaac-sim/cache/glcache:/root/.cache/nvidia/GLCache:rw \
-v ~/docker/isaac-sim/cache/computecache:/root/.nv/ComputeCache:rw \
-v ~/docker/isaac-sim/logs:/root/.nvidia-omniverse/logs:rw \
-v ~/docker/isaac-sim/data:/root/.local/share/ov/data:rw \
-v ~/docker/isaac-sim/documents:/root/Documents:rw \
276226212704.dkr.ecr.us-gov-west-1.amazonaws.com/tiamat/baseline:latest


bash run_eval.sh --rr

ros2 topic list --no-daemon

conda activate tiamat-habitat
export DISPLAY=:1
python /root/habitat_environment/sim/tiamat_runner.py --final

on vino:

ROS_DISTRO=humble ~/zenoh-plugin-ros2dds/target/release/zenoh-bridge-ros2dds -e tcp/141.212.194.241:7447

docker run --gpus '"device=1"' --network host -t tiamat-test-agent

ros2 topic pub /task_submission std_msgs/msg/String "data: '/spot/camera/head_rgb_left/image/compressed, (576, 192, 384, 0, 768, 384), top-right crop'" --once
ros2 topic pub /sim_control std_msgs/msg/String "data: 'task complete'" --once