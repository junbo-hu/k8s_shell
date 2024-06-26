#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-04-17
# *************************************

mark_print(){
  mark=''
  num=1
  while [ ${num} -le 3 ]; do
    while [ "${ver}" != "v2.0" ]; do
      printf "progress: [%-40s]\r" "${mark}"
      sleep 0.2
      mark="#${mark}"
      # 解决换行的问题
      mark_array=($(echo ${mark}))
      mark_length=${#mark_array}
      if [ ${mark_length} -gt 10 ]; then
        mark=""
        break
      fi
    done
    let num+=1
    echo "---$num---"
  done
}

mark_print
