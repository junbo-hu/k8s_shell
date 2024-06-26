#!/bin/bash
# expect的shell脚本使用方式

# expect多内容匹配
/usr/bin/expect -c "
  # 监听涉及用户交互的命令
  spawn ssh root@10.0.0.12
  # expect多内容匹配
  expect {
    \"yes/no\" {send \"yes\r\"; exp_continue}
    \"password:\" {send \"123456\r\"; exp_continue}
    \"password:\" {send \"123456\r\"}
  }
"

# shell内容操作
ifconfig
