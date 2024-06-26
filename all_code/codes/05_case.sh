#!/bin/bash
# case语句的演示

# 基础内容
arg="$1"

case "${arg}" in
  "start")
     echo "systemctl start service";;
  "restart")
     echo "systemctl restart service";;
  "stop")
     echo "systemctl stop service";;
  *)
     echo "Usage: xxx";;
esac
