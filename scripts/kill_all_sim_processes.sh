#!/bin/sh

# kill simulator
echo "Killing all top-level simulator processes..."
killall -9 "iPhone Simulator"

# kill xpcproxy_sim zombies by explicitly killing parent process
echo "Killing any xpcproxy_sim zombies..."
ps -edf | \
 grep [x]pcproxy_sim | awk '{print $3}' | \
 sort | uniq | \
 xargs -I{} echo "kill -9 {}" | sh
