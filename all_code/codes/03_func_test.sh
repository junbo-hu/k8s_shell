#!/bin/bash
# read 演示

# 用户交互操作部分
read -p "请输入要连接的主机ip地址: " host_addr
read -p "请输入要连接的主机用户名: " host_user
echo "您要连接的远程主机是: ${host_user}@${host_addr}"
# 功能执行部分
ssh "${host_user}@${host_addr}"
