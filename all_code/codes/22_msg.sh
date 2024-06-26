#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-12-04
# *************************************

# 功能：旋转进度
# 类似旋转的符号： \ | / --

# 定制旋转函数
waiting(){
  # 定制初始参数
  time=0
  while [ $time -lt 10 ]; do
  # 开始循环
    for tag in "\\" "|" "/" "-"; do
      # 循环遍历符号
      printf "%c\r" "$tag"
      sleep 0.2
    done
    # 结束(-10s)
    let time+=1
  done
}

waiting
