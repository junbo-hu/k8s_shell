#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-04-15
# *************************************

# 场景示例: ip_list

# 展示内容
echo '$@ 的循环遍历'
for i in "$@"
do
  echo $i
done

echo '$* 的循环遍历'
for i in "$*"
do
  echo $i
done
