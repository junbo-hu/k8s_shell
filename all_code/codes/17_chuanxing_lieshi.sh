#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-04-22
# *************************************
for i in $(seq 1 20); do echo "---$i---"; sleep 0.1; done &
for i in $(seq 1 20); do echo "===$i==="; sleep 0.1; done &
for i in $(seq 1 20); do echo "+++$i+++"; sleep 0.1; done &
for i in $(seq 1 20); do echo "((($i)))"; sleep 0.1; done &
