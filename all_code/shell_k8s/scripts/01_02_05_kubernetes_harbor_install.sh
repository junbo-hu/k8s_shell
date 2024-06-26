#!/bin/bash
# *************************************
# 功能: 控制节点执行harbor环境部署
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-07-17
# *************************************

# 定制harbor离线文件的传输
scp_harbor_file(){
  if [ ! -f "${harbor_dir}/${harbor_softs}" ]; then 
    echo -e "\e[33m部署主机不存在 ${harbor_softs} 文件，请提前获取!!!\e[0m"
    exit
  else
    remote_status=$(ssh "${login_user}@${harbor_addr}" "[ -f ${target_dir}/${harbor_softs} ] && echo exists")
    if [ "${remote_status}" == "exists" ]; then
      echo -e "\e[33m远程主机已存在 ${harbor_softs} 文件!!!\e[0m"
    else
      ssh "${login_user}@${harbor_addr}" "mkdir -p ${target_dir}"
      scp "${harbor_dir}/${harbor_softs}" "${login_user}@${harbor_addr}:${target_dir}/"
      echo -e "\e[33m离线文件 ${harbor_softs} 文件，以传输到harbor远程主机!!!\e[0m"
    fi
  fi
}
# harbor用户定制
harbor_user(){
  # 接收环境变量
  user="$1"
  passwd="$2"
  # 定制harbor管理员用户配置
  cat > /tmp/add_user.json<<-eof
{
  "username": "${user}",
  "realname": "${user}",
  "email": "${user}@sswang.com",
  "password": "${passwd}",
  "comment": "普通用户"
}
eof
  # 检查用户
  result=$(curl -s -H "Content-Type: application/json" -u "${harbor_admin}:${harbor_admin_passwd}" "${harbor_url}/${user_api}" | grep "${user}")
  if [ "${result}" != "" ]; then
    echo -e "\e[32m${user}用户已创建成功!!!\e[0m"
  else
    # 创建用户
    curl -s -H "Content-Type: application/json" -u "${harbor_admin}:${harbor_admin_passwd}" -X POST "${harbor_url}/${user_api}" -d @/tmp/add_user.json
    echo -e "\e[31m${user}用户创建成功!!!\e[0m"
    # exit
  fi
}

# harbor镜像仓库
harbor_proj(){
  # 接收环境变量
  user="$1"
  passwd="$2"
  repo="$3"
  # 定制harbor镜像仓库配置
  cat > /tmp/add_repo.json <<-eof
{
  "project_name": "${repo}",
  "public": true
}
eof
  
  # 检测harbor镜像仓库
  result=$(curl -s -H "Content-Type: application/json" -u "${user}:${passwd}" "${harbor_url}/${proj_api}" | grep "${repo}")
  if [ "${result}" != "" ]; then
    echo -e "\e[32m${repo}仓库已创建成功!!!\e[0m"
  else
    # 创建harbor镜像仓库
    curl -s -H "Content-Type: application/json" -u "${user}:${passwd}" -X POST "${harbor_url}/${proj_api}" -d @/tmp/add_repo.json
    echo -e "\e[31m${repo}仓库创建成功!!!\e[0m"
    # exit
  fi
}

# harbor环境检查
harbor_check(){
  # 检查harbor的应用环境
  echo -e "\e[31m检测harbor程序状态是否正常\e[0m"
  local status=$(ssh ${login_user}@${harbor_addr} "systemctl is-active harbor")
  if [ "${status}" == "active" ]; then
    echo -e "\e[32mharbor镜像仓库环境部署成功!!!\e[0m"
  else
    echo -e "\e[31mharbor镜像仓库环境部署失败!!!\e[0m"
    exit
  fi
  # 检查harbor的api服务环境
  echo -e "\e[31m检测harbor服务状态是否正常\e[0m"
  local msg=$(curl -s "${harbor_url}/${harbor_ver}")
  local ver=$(echo "${msg}" | jq -r ".version")
  local mark=''
  local num=1
  while [ ${num} -le 3 ]; do
    # 如果状态正常，则直接进行下一步
    [ "${ver}" = "v2.0" ] && break
    while [ "${ver}" != "v2.0" ]; do
      printf "progress: [%-40s]\r" "${mark}"
      sleep 0.5
      local mark="#${mark}"
      # 解决内容过多导致信息满屏的问题
      local mark_array=($(echo ${mark}))
      local mark_length=${#mark_array}
      if [ ${mark_length} -gt 40 ]; then
        local mark=""
        # 一次判断异常，则重启harbor后，再次检测
        ssh ${login_user}@${harbor_addr} "systemctl restart harbor"
        break
      fi
      msg=$(curl -s "${harbor_url}/${harbor_ver}")
      ver=$(echo "${msg}" | jq -r ".version")
    done
    let num+=1
  done
  echo -e "\e[32m检测harbor API服务状态正常\e[0m"
}

# 登录函数
login_remote_harbor(){
  # 接收参数
  local remote_addr="$1"
  
  # master节点登录harbor仓库
  echo -e "\e[33m登录本地harbor镜像仓库!!!\e[0m"
  harbor_login_cmd="docker login ${harbor_url} -u ${harbor_user} -p ${harbor_passwd}"
  ssh ${login_user}@${remote_addr} "${harbor_login_cmd}"
}

# 导入镜像文件函数
harbor_repo_load_image(){
  # 接收参数
  local repo_name="$1"
  local repo_base_dir="$2"
  local remote_addr="$3"
  
  # 定制harbor镜像文件的备份目录
  local harbor_repo_path="${repo_base_dir}/${repo_name}"
  # 获取harbor地址的长域名
  local harbor_addr=$(get_remote_node_name "${remote_addr}" "long")

  # 注意：有可能后期仓库域名更改，所以这里原则上需要判断镜像的仓库域名是否一致
  for image_file in $(ssh ${login_user}@${remote_addr} "ls ${harbor_repo_path}"); do
    local image_name=$(echo ${image_file%.tar})
    local image_url_name="${harbor_addr}/${repo_name}/${image_name}"
    # 判断harbor仓库中是否存在镜像
    
    local image_status_check=$(harbor_repo_image_file_exist_check "${image_url_name}")
    if [ "${image_status_check}" == "is_exist" ];then
      echo -e "\e[32m${image_url_name}在镜像仓库已存在，无需重复导入!!!\e[0m"
    else
      ssh ${login_user}@${remote_addr} "docker load < ${harbor_repo_path}/${image_file}; \
                                        docker push ${image_url_name}"
      echo -e "\e[32m${image_url_name}镜像文件已上传到harbor镜像仓库!!!\e[0m"
    fi
  done
}

# 导入备份镜像总函数
harbor_deploy_after_load_image(){
  # 接收参数
  local remote_addr="$1"
  local harbor_backup_dir="${default_backup_dir}/harbor"

  # 获取备份文件仓库目录列表
  local repo_list=$(ssh ${login_user}@${remote_addr} "ls ${harbor_backup_dir}")
  if [ ! -z "${repo_list}" ]; then
    # 创建仓库名字
    for repo_name in ${repo_list}; do
      harbor_proj "${harbor_user}" "${harbor_passwd}" "${repo_name}"
    done

    # 登录远程主机
    login_remote_harbor "${remote_addr}"
  
    # 导入所有仓库目录下的镜像文件
    for repo_name in ${repo_list}; do
      harbor_repo_load_image "${repo_name}" "${harbor_backup_dir}" "${remote_addr}"
    done
  fi
}
# 主函数
main(){
  # 控制节点获取harbor文件
  scp_harbor_file
  # 安装检测命令 jq
  rm -rf /var/lib/dpkg/lock*
  "${cmd_type}" install jq -y
  # 指挥远程harbor主机部署harbor
  remote_harbor_status=$(ssh "${login_user}@${harbor_addr}" "systemctl is-active ${harbor_name}")
  if [ "${remote_harbor_status}" == "active" ]; then
    echo -e "\e[32m${harbor_addr} 主机harbor服务已部署成功\e[0m"
  else
    if [ -f "${scripts_dir}/${base_harbor_remote_scripts}" ]; then
      scp "${scripts_dir}/${base_harbor_remote_scripts}" "${login_user}@${harbor_addr}:/tmp/"
      ssh "${login_user}@${harbor_addr}" "/bin/bash /tmp/${base_harbor_remote_scripts}"
    fi
  fi
  # 远程检测harbor主机服务是否正常
  harbor_check
  # harbor仓库服务定制
  harbor_user "${harbor_user}" "${harbor_passwd}"
  harbor_proj "${harbor_user}" "${harbor_passwd}" "${harbor_my_repo}"  
  harbor_proj "${harbor_user}" "${harbor_passwd}" "${harbor_k8s_repo}"  

  # 获取所有镜像文件
  get_harbor_all_repo_image_list

  # 导入备份文件
  if [ "${backup_image_load_harbor}" == "yes" ]; then
    harbor_deploy_after_load_image "${harbor_addr}"
  fi
}

# 执行主函数
main
