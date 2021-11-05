#!/bin/bash

ping -c 1 $PC_REMOTE_IP > /dev/null

if [ $? -eq 0 ]; then
  # SERVER IS UP
  echo "UP!"
else
  # SERVER IS DOWN
  echo "DOWN!"
fi