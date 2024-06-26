#!/bin/bash
# *************************************
# 功能: 解决master节点是Ubuntu系统
#       node解决是Centos系统的匹配问题
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-01-25
# *************************************

# 判断目录是否存在
resolv_dir='/run/systemd/resolve'
resolv_file='resolv.conf'

# Centos处理不存在文件
[ -d "${resolv_dir}" ] || mkdir -p "${resolv_dir}"
if [ ! -f "${resolv_dir}/${resolv_file}" ]; then
  ln -s "/etc/${resolv_file}" "${resolv_dir}/${resolv_file}"
fi
