#!/bin/sh

# kill simulator
killall -9 "iPhone Simulator"

# kill xpcproxy_sim zombies by explicitly killing parent process
ps -edf | \
 grep [x]pcproxy_sim | awk '{print $3}' | \
 sort | uniq | \
 xargs -I{} echo "kill -9 {}" | sh