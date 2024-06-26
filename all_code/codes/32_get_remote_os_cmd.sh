#!/bin/bash
# *************************************
# 功能: 获取远程主机的操作系统相关信息
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 微信群: 自学自讲—软件工程
# 抖音号: sswang_yys 
# 版本: v0.1
# 日期: 2024-05-12
# *************************************

# 接收参数
host_type="$1"
remote_addr="$2"
login_user='root'

# 定制获取远程主机操作系统类型函数
get_remote_os_type(){
  # 接收参数
  local host_type="$1"
  local remote_addr="$2"

  # 判断逻辑
  if [ "${host_type}" == "local" ]; then
    exec_cmd='grep -i ubuntu /etc/issue'
  elif [ "${host_type}" == "remote" ]; then
    exec_cmd="ssh ${login_user}@${remote_addr} grep -i ubuntu /etc/issue"
  else
    echo -e "\e[31m请输入有效的主机类型(示例: local|remote)...\e[0m"
  fi

  # 获取远程主机的操作系统类型
  ${exec_cmd} >/dev/null && local os_type="Ubuntu" || local os_type="CentOS"
  echo "${os_type}"
}

# 定制远程主机软件操作命令函数
get_remote_cmd_type(){
  # 接收参数
  local host_type="$1"
  local remote_addr="$2"

  # 判断逻辑
  local remote_os_type=$(get_remote_os_type "${host_type}" "${remote_addr}")

  # 定制远程主机软件操作命令
  if [ "${os_type}" == "CentOS" ]; then
    local os_cmd_type="yum"
  else
    local os_cmd_type="apt-get"
  fi
  echo "${os_cmd_type}"
}

echo "测试操作系统类型以及相关命令"
echo "remote | local"
get_remote_os_type "${host_type}" "${remote_addr}"
get_remote_cmd_type "${host_type}" "${remote_addr}"

