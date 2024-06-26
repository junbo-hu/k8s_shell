#!/bin/bash
# *************************************
# 功能: 主功能函数所依赖的功能函数
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-04-13
# *************************************

# 定制基础环境变量
expect_cmd='/usr/bin/expect'

# 定制获取远程主机操作系统类型函数
get_remote_os_type(){
  # 接收参数
  local host_type="$1"
  local remote_addr="$2"
 
  # 判断逻辑
  if [ "${host_type}" == "local" ]; then
    exec_cmd="grep -i ubuntu /etc/issue"
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
  if [ "${remote_os_type}" == "CentOS" ]; then
    local os_cmd_type="yum"
  else
    local os_cmd_type="apt"
  fi
  echo "${os_cmd_type}"
}

# 获取IP地址对应的主机名
get_remote_node_name(){
  # 接收参数
  local remote_addr="$1"
  local name_type="$2"

  # 获取逻辑
  case "${name_type}" in
    "long")
      local host_name=$(grep "${remote_addr}" "${host_file}" | awk '{print $2}');;
    "short")
      local host_name=$(grep "${remote_addr}" "${host_file}" | awk '{print $3}');;
    *)
      echo -e "\e[31m请输入有效的主机名类型(long|short)...\e[0m"
  esac
  echo "${host_name}"
}

# 获取远程主机的集群角色
get_remote_node_role(){
  # 接收参数
  local remote_addr="$1"
  
  # 判断逻辑
  local node_name=$(grep "${remote_addr}" "${host_file}" | awk '{print $NF}')
  if [[ "${node_name}" =~ .*node.*$ ]]; then
    local node_role="node"
  elif [[ "${node_name}" =~ .*master.*$ ]]; then
    local node_role="master"
  fi

  echo "${node_role}"
}
# expect在线部署逻辑函数
expect_install_online(){
  # 指定安装
  "${cmd_type}" install expect -y && echo -e "\e[32mexpect软件安装成功!!!\e[0m" || (echo -e "\e[32mexpect软件安装失败!!!\e[0m" && exit)
}

# expect离线部署逻辑函数
expect_install_offline(){
  # 根据操作系统的区别来判断文件目录
  if [[ "${os_type}" == "CentOS" ]]; then
    if [ -f ${expect_centos_dir}/expect*.rpm ];then
      echo -e "\e[33m以离线线方式部署expect\e[0m"
      "${cmd_type}" install -y ${expect_centos_dir}/*
    else
      echo -e "\e[33m指定目录下没有expect离线软件，请提前准备!!!\e[0m"
      exit
    fi
  else
    # 首先判断是否存离线文件，若存在则部署，否则下载文件后，提示安装
    if [ -f ${expect_ubuntu_dir}/expect*.deb ];then
      echo -e "\e[33m以离线线方式部署expect\e[0m"
      dpkg -i ${expect_ubuntu_dir}/*
    else
      echo -e "\e[33m指定目录下没有expect离线软件，请提前准备!!!\e[0m"
      exit
    fi
  fi

}

# expect环境部署
expect_install(){
  # 判断expect是否安装
  if [ -f "${expect_cmd}" ]; then
    echo -e "\033[31mexpect环境已经部署完毕了!!!\033[0m"
  else
    # 安装expect
    read -t 10 -p "请输入您准备以哪种方式安装expect(online|offline): " install_type
    # install_type=${install_type:-online}
    [ -n "${install_type}" ] && install_type="${default_deploy_type+${install_type}}" || install_type="${default_deploy_type}"
    if [ "${install_type}" == "online" ]; then
      echo -e "\e[33m以在线方式部署expect\e[0m"
      expect_install_online
    else
      expect_install_offline
    fi
  fi  
}

# ssh秘钥生成
sshkey_create(){
  current_user=$(whoami)
  [ "${current_user}" == "root" ] && user_dir='/root' || user_dir="/home/${current_user}"
  
  # 是否重置ssh现有的秘钥对儿
  if [ "${k8s_cluster_create_reset_ssh}" == "yes" ]; then
    [ -d "${user_dir}/.ssh" ] && rm -rf "${user_dir}/.ssh"
    # 生成ssh秘钥对儿
    ssh-keygen -t rsa  -P "" -f "${user_dir}/.ssh/id_rsa"

    # 生成配套的known_hosts空文件
    > "${user_dir}/.ssh/known_hosts"
  fi

  echo -e "\e[32mssh秘钥对儿创建完毕!!!\e[0m"
}

# hosts文件生成
hosts_create(){
  # 优化1：考虑创建hosts文件时的旧有记录处理
  for i in $(awk '/kuber/{print $1}' "${conf_dir}/${host_name}");do
    sed -i "/$i/d" "${host_file}"
  done
  # 增加当前集群的节点主机名解析记录
  awk '$0~"kubernetes-"{print $1,$2".sswang.com",$2}' "${conf_dir}/${host_name}" >> "${host_file}"
  echo -e "\e[32mhosts文件创建完毕!!!\e[0m"
}

# bug修复: 新增ip地址准备工作函数
check_ipaddr(){
  # 接收参数
  local ip="$1"
  # 判断ip地址是否存在
  local ip_status=$(grep ${ip} ${host_file} >/dev/null && echo "is_exist" || echo "no_exist")
  if [ "${ip_status}" == "no_exist" ]; then
    # 定制 短域名
    local node_num=$(awk -F"node" '/node/{print $NF}' "${conf_dir}/${host_name}" | tail -1)
    let new_node_num=node_num+1
    local new_node_name="kubernetes-node${new_node_num}"

    # 更新 conf/hosts 文件
    # 在最后一个node节点的下一行增加
    sed -i "/node${node_num}/a${ip} ${new_node_name}" "${conf_dir}/${host_name}"

    # 更新 /etc/hosts 文件
    sed -i "/node${node_num}/a${ip} ${new_node_name}.sswang.com ${new_node_name}" "${host_file}"
  fi
}

# 检测节点ssh秘钥是否存在
sshkey_auth_exist_check(){
  # 接收参数
  local remote_addr="$1"

  # 检测节点认证记录是否存在
  local host_status=$(ssh-keygen -l -F ${remote_addr} >/dev/null && echo "is_exist" || echo "no_exist")
  echo "${host_status}"
}

# 删除指定节点的ssh认证秘钥
sshkey_auth_exist_delete(){
  # 接收参数
  local remote_addr="$1"
  
  # 检测主机ssh秘钥记录
  local host_status=$(sshkey_auth_exist_check "${remote_addr}")
  if [ "${host_status}" == "is_exist" ]; then
    # 清理已存在主机记录
    ssh-keygen -f "/root/.ssh/known_hosts" -R "${remote_addr}"
    echo -e "\e[32m主机 $remote_addr ssh认证信息已删除!!!\e[0m"
  else
    echo -e "\e[33m主机 $remote_addr ssh认证信息不存在!!!\e[0m"
  fi
}

# ssh 跨主机免密码认证
sshkey_auth_func(){
  # 接收参数
  local ip_list="$*"
  # 执行跨主机免密码操作
  local cmd="ssh-copy-id -i $HOME/.ssh/id_rsa.pub "
  for ip in ${ip_list}; do
    # bug修复: 新增ip地址时跨主机免密码认证异常
    check_ipaddr "${ip}"
    # 主机名解析记录，在多种场景下，长短主机名都可能用到，所以这三个都做认证
    for addr in $(grep $ip ${host_file}); do
      # bug修复: 清理已存在的跨主机免密码记录
      # local host_status=$(ssh-keygen -l -F ${addr} >/dev/null && echo "is_exist" || echo "no_exist")
      # if [ "${host_status}" == "is_exist" ]; then
        # 清理已存在主机记录
      #   ssh-keygen -f "/root/.ssh/known_hosts" -R "${addr}"
      # fi
      sshkey_auth_exist_delete "${addr}"
      # 借助循环构造多格式主机目标
      local target="${login_user}@${addr}"
      expect_autoauth_func "${cmd}" "${target}"
      echo -e "\e[32m主机 $addr 已经实现跨主机免密码认证!!!\e[0m"
    done
  done
}

# expect 实现自动化命令执行
expect_autoauth_func(){
  # 接收参数
  local remote_cmd="$*"
  # expect的全程干预
  /usr/bin/expect -c "
    spawn ${remote_cmd}
    expect {
      \"yes/no\" {send \"yes\r\"; exp_continue}
      \"*password*\" {send \"${login_pass}\r\"; exp_continue}
      \"*password*\" {send \"${login_pass}\r\"}
    }"
}

# 远程传输文件
scp_file_bak(){
  # 接收参数
  local ip_list="$*"
  # 远程传输文件
  for ip in ${ip_list}; do
   scp "${host_file}" "${login_user}@${ip}:${host_file}"
  done
}

scp_file(){
  # 接收参数
  local target_dir=$(echo $* | awk '{print $NF}')
  local source_file=$(echo $* | awk '{print $(NF-1)}')
  local ip_list=$(echo $* | awk '{$NF=null;$(NF-1)=null;print $0}')
  local filename=$(basename ${source_file})
  local target_file="${target_dir}/${filename}"
  # 远程传输文件
  for ip in ${ip_list}; do
    scp "${source_file}" "${login_user}@${ip}:${target_file}"
  done
}

# 传递hosts文件
scp_hosts_file(){
  # 接收参数
  local target_dir=$(echo $* | awk '{print $NF}')
  local source_file=$(echo $* | awk '{print $(NF-1)}')
  local ip_list=$(echo $* | awk '{$NF=null;$(NF-1)=null;print $0}')
  local filename=$(basename ${source_file})
  local target_file="${target_dir}/${filename}"

  # 检测文件内容是否一致
  for ip in ${ip_list}; do
    # 获取远程主机的hosts文件内容
    ssh "${login_user}@${ip}" "cat ${target_file}" > "/tmp/${host_name}"
    # 对比文件内容，确定是否拷贝文件
    host_context_status=$(diff ${target_file} /tmp/${host_name} >/dev/null \
                          && echo "same" || echo "unsame")
    if [ "${host_context_status}" == "same" ]; then
      echo -e "\033[32m主机 ${ip} hosts文件已同步，无需更新!!!\033[0m"
    else
      scp_file ${ip} "${host_file}" "${host_target_dir}"
    fi
  done
}

# 跨主机设定主机名
set_hostname(){
  # 接收参数
  local ip_list="$*"
  # 远程执行命令
  for ip in ${ip_list}; do
    local remote_host="${login_user}@${ip}"
    local hostname=$(grep ${ip} ${host_file} | awk '{print $NF}')
    ssh ${remote_host} "hostnamectl set-hostname ${hostname}"
  done
}

# 生成ip列表
create_ip_list(){
  # 接收参数
  local ip_net="$1"
  local ip_tail="$2"
  local ip_list=""
  # 生成ip列表
  for i in $(eval echo ${ip_tail}); do
    ip_addr=$(echo -n "${ip_net}.${i} ")
    ip_list="${ip_list}${ip_addr}"
  done
  echo "${ip_list}"
}

# 软件源同步
repo_update(){
  # 接收参数
  local ip_list="$*"

  # 远程执行更新命令
  for ip in ${ip_list}; do
    remote_os_status=$(ssh "${login_user}@${ip}" "grep -i ubuntu /etc/issue")
    [ -n "${remote_os_status}" ] && local os_type="Ubuntu" || local os_type="CentOS"
    if [ "${os_type}" == "CentOS" ]; then
      ssh "${login_user}@${ip}" "yum makecache fast"
    else
      ssh "${login_user}@${ip}" "rm -rf /var/lib/dpkg/lock*; apt update"
    fi
    echo -e "\033[32m主机 ${ip} 软件源更新完毕!!!\033[0m"
  done
}

# 输出符号
echo_tag(){
  # 常见方法：
  # echo {1..30} | sed 's/[0-9]/=/g' | sed 's/ //g' 
  # seq -s "=" 100 | sed 's/[0-9]//g'
  # echo | awk '{for(i=1;i<=100;i++){printf "="}}{printf "\n"}'

  # 接收参数
  tag="$1"
  num="$2"
  
  # 输出指定长度的内容
  seq -s "${tag}" ${num} | sed 's/[0-9]//g'
}

# 输出绝对值函数
echo_abs(){
  # 接收参数
  local num="$1"
  if (($num>=0));then
    # 如果是正数，则直接输出
    echo $num
  else
    # 如果是负数，则输出正数
    echo $((-$num));
  fi  
}

# 定制旋转函数
waiting(){
  # 接收参数
  local end_time="$1"
  # 定制初始参数
  time=0
  while [ $time -lt "$end_time" ]; do
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

# 定制一键通用基础环境功能函数
one_key_base_env(){
  # 功能逻辑
  echo -e "\e[33m开始执行基本环境部署...\e[0m"
  expect_install
  sshkey_create
  hosts_create
  echo -e "\e[33m开始执行跨主机免密码认证...\e[0m"
  sshkey_auth_func "${all_node_list}"
  echo -e "\e[33m开始执行同步集群hosts...\e[0m"
  scp_hosts_file ${all_node_list} "${host_file}" "${host_target_dir}"
  echo -e "\e[33m开始执行设定集群主机名...\e[0m"
  set_hostname ${all_node_list}
  echo -e "\e[33m开始执行更新软件源...\e[0m"
  repo_update "${all_node_list}"
}
