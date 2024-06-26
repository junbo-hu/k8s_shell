#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-04-15
# *************************************

# 查看 $@ 和 $* 看起来基本一样
echo "$0 文件获取的所有参数: $@"
echo "$0 文件获取的所有参数: $*"

# 确认 $@ 和 $* 的类型到底有什么区别
echo '$@ 传递内容给子脚本: ' $@
# /bin/bash 14_child.sh "$@"
/bin/bash 15_child.sh "$@"
echo '$* 传递内容给子脚本: ' $*
# /bin/bash 14_child.sh "$*"
/bin/bash 15_child.sh "$*"

# 刚才为什么出现问题，结果是一样的？
# /bin/bash 14_child.sh arg1 arg2 arg3 arg4
