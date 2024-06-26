#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-02-02
# *************************************
abs(){
  local num="$1"
    if (($num>=0));then
        echo $num
    else
        echo $((-$num));
    fi
}

abs "$1"
