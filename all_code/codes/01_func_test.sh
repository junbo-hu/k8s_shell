#!/bin/bash
# $0 获取文件名 
# $n 获取参数值
# $# 获取参数个数


# $0 演示
# echo "Usage: /bin/bash func_test.sh"
# echo "Usage: /bin/bash $0"

# $n 演示
# echo "第一个位置参数值: $1"
# echo "第二个位置参数值: $2"
# echo "第三个位置参数值: $3"
# echo "第四个位置参数值: $4"

# $# 演示
# echo "脚本传入的参数个数: $#"
if [ "$#" -eq 2 ] 
then
  echo "执行脚本内容"
else
  echo "Usage: /bin/bash $0 arg1 arg2"
fi
