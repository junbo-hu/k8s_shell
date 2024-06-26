#!/bin/bash
# *************************************
# 功能: Shell 串行执行动作
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-04-22
# *************************************

# 设定起始时间
start_time=$(date +%s)
# 循环逻辑操作
for i in $(seq 1 20); do
  echo "num=$i"
  sleep 1
done
# 设定结束时间
stop_time=$(date +%s)

# 结果输出
echo "程序执行时长: $(expr $stop_time - $start_time)"
