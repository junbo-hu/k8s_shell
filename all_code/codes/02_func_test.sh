#!/bin/bash
# ${var:-default} 如果var为空，则输出default
# ${var+default}  始终输出default


# ${var:-default} 演示
# local_var="$1"
# echo "您选择的手机流量套餐是: ${local_var:-1} 套餐"

# ${var+default} 演示
local_var="$1"
echo "您觉得我国男性的法定结婚年龄是: ${local_var+20} 岁"
