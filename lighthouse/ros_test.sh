# on server
ros2 topic echo /tcp_test_topic std_msgs/msg/String
# on client
ros2 topic pub --rate 1 /tcp_test_topic std_msgs/msg/String "data: 'Hello from Client via TCP'"
# Success: You should see "data: 'Hello from Client via TCP'" appearing on your Server's terminal.


# on client
ros2 topic echo /tcp_test_topic std_msgs/msg/String
# on server
ros2 topic pub --rate 1 /tcp_test_topic std_msgs/msg/String "data: 'Hello from Server via TCP'"
# Success: You should see the message appearing on your Client's terminal.