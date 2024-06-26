#!/bin/bash
# *************************************
# 功能: Shell脚本读取文件
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 微信群: 自学自讲—软件工程
# 抖音号: sswang_yys 
# 版本: v0.1
# 日期: 2024-05-16
# *************************************

filename="/etc/hosts"

read_file(){
  filename="$1"

  while read line
  do
    echo $line
  done <  ${filename}
}

read_file "${filename}"
