#!/bin/sh

# kill simulator
echo "Killing all top-level Xcode 5 simulator processes..."
killall -9 "iPhone Simulator" 2>&1
echo "Killing all top-level Xcode 6 simulator processes..."
killall -9 "iOS Simulator" 2>&1

echo "Killing ScriptAgent..."
killall -9 "ScriptAgent" 2>&1

# kill xpcproxy_sim zombies by explicitly killing parent process
echo "Killing any xpcproxy_sim zombies..."
ps -edf | \
 grep [x]pcproxy_sim | awk '{print $3}' | \
 sort | uniq | \
 xargs -I{} echo "kill -9 {} 2>&1" | sh
