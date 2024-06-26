#!/bin/bash
# 父脚本操作

# 接收脚本参数
sub_scripts="$1"

# 定义全局变量
export xing="王"

# 定义两个本地变量
ming="树森"
age="37"

# 信息输出
echo "父脚本: ${xing}${ming},${age}"

# 调用子脚本
sleep 3
/bin/bash ${sub_scripts}
