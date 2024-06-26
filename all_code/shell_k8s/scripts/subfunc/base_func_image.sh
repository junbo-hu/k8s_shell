#!/bin/bash
# *************************************
# 功能: 镜像相关的信息获取
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-01-10
# *************************************

# 基于仓库获取所有镜像列表
get_proj_image_list(){
  # 接收参数
  local project_name="$1"
  local is_append="$2"

  # bug修复: 解决harbor的 http 和 https的访问异常
  local curl_option=$([ "${harbor_http_type}" == "https" ] && echo "-k")  
  # 获取所有的镜像名称
  # > "${harbor_images_list_file}"
  [ "${is_append}" == "yes" ] && local append_type='>>' || local append_type='>'
  ${append_type} "${harbor_images_list_file}"
  # 为了避免对上层函数造成影响，这里使用local
  local images_list=$(curl ${harbor_url}/${image_api}${project_name} -s ${curl_option} | jq '.repository[].repository_name' | awk -F'"|/' '{print $3}')
  for image in ${images_list}; do
    # 获取指定镜像的标签
    tag_list=$(curl ${harbor_url}/${proj_api}/${project_name}/repositories/${image}/artifacts -s ${curl_option} | jq '.[].tags[].name' | awk -F'"' '{print $2}')
    for tag in ${tag_list}; do
      echo "${harbor_addr}/${project_name}/${image}:${tag}" >> "${harbor_images_list_file}"
    done
  done
}

# 获取harbor仓库的所有镜像文件
get_harbor_all_repo_image_list(){
  # 定制参数
  local curl_option=$([ "${harbor_http_type}" == "https" ] && echo "-k")
  
  # 准备文件
  > "${harbor_images_list_file}"

  # 获取所有的镜像仓库地址
  projects_list=$(curl ${harbor_url}/${proj_api} -s ${curl_option} | jq '.[].name' | awk -F '"' '{print $2}')
  for project_name in ${projects_list}; do
    # yes 以 追加 方式填充文件列表
    get_proj_image_list "${project_name}" "yes"
  done
}
 
# 检测备份文件是否存在
harbor_repo_image_file_backup_check(){
  # 接收参数
  local harbor_repo_name="$1"
  local harbor_file_name="$2"

  # 判断备份文件是否存在
  local harbor_file_status=$(ssh "${login_user}@${harbor_addr}" " \
                             [ -f ${harbor_backup}/${harbor_repo_name}/${harbor_file_name}.tar ]" \
                             && echo "is_exist" || echo "no_exist")
  echo "${harbor_file_status}"
}

# 创建镜像备份文件所在目录
harbor_repo_image_file_backup_dir_create(){
  # 接收参数
  local harbor_repo_name="$1"
  local harbor_repo_dir="${harbor_backup}/${harbor_repo_name}"
  # 创建备份文件目录
  ssh "${login_user}@${harbor_addr}" "[ -d ${harbor_repo_dir} ] \
                                      || mkdir -p ${harbor_repo_dir}"
}

# 执行harbor仓库备份文件
harbor_repo_image_file_backup_logic_bak(){
  # 接收参数
  local harbor_repo_file="$1"
  local harbor_repo_name=$(echo ${harbor_repo_file} | awk -F'/' '{print $2}')
  local harbor_file_name=$(echo ${harbor_repo_file} | awk -F'/' '{print $NF}')
  local harbor_repo_dir="${harbor_backup}/${harbor_repo_name}"

  # 判断harbor仓库中是否存在镜像
  local image_status_check=$(harbor_repo_image_file_exist_check "${harbor_repo_name}" "${harbor_file_name}")
  if [ "${image_status_check}" == "is_exist" ];then
    echo -e "\e[32m${harbor_repo_file}在镜像仓库已存在，无需重复导入!!!\e[0m"
  else
    # 执行备份文件导入动作
    local backup_file_status=$(harbor_repo_image_file_backup_check \
                               "${harbor_repo_name}" "${harbor_file_name}")
    if [ "${backup_file_status}" == "no_exist" ];then
      ssh "${login_user}@${harbor_addr}" "docker pull ${harbor_repo_file}; \
                                          docker save -o ${harbor_repo_dir}/${harbor_file_name}.tar \
                                          ${harbor_repo_file}; \
                                          docker rmi ${harbor_repo_file}"
    fi
  fi
}

harbor_repo_image_file_backup_logic(){
  # 接收参数
  local harbor_repo_file="$1"
  local harbor_repo_name=$(echo ${harbor_repo_file} | awk -F'/' '{print $2}')
  local harbor_file_name=$(echo ${harbor_repo_file} | awk -F'/' '{print $NF}')
  local harbor_repo_dir="${harbor_backup}/${harbor_repo_name}"

  # 执行备份文件导入动作
  local backup_file_status=$(harbor_repo_image_file_backup_check \
                             "${harbor_repo_name}" "${harbor_file_name}")
  if [ "${backup_file_status}" == "no_exist" ];then
    ssh "${login_user}@${harbor_addr}" "docker pull ${harbor_repo_file}; \
                                        docker save -o ${harbor_repo_dir}/${harbor_file_name}.tar \
                                        ${harbor_repo_file}; \
                                        docker rmi ${harbor_repo_file}"
  fi
}
# 备份所有的镜像文件
harbor_repo_image_file_backup(){
  # 生成harbor所有镜像文件
  get_harbor_all_repo_image_list
  
  # 创建创建备份目录
  local harbor_repo_list=$(awk -F'/' '{print $2}' "${harbor_images_list_file}"  | uniq)
  for repo_name in ${harbor_repo_list}; do
    harbor_repo_image_file_backup_dir_create "${repo_name}"
  done


  # 读取所有的harbor镜像文件列表
  for line in $(cat "${harbor_images_list_file}")
  do
    # 执行镜像文件备份
    harbor_repo_image_file_backup_logic "${line}"
  done
  # while read line
  # do
    # 执行镜像文件备份
  #   harbor_repo_image_file_backup_logic "${line}"
  #   echo "${line}"
  #   sleep 1
  # done <  "${harbor_images_list_file}"
}

# 检测仓库镜像是否存在
harbor_repo_image_file_exist_check(){
  # 接收参数
  local harbor_image_name="$1"

  # 判断文件是否存在
  local check_image_status=$(grep "${harbor_image_name}" \
                             "${harbor_images_list_file}" >>/dev/null 2>&1 \
                             && echo "is_exist" || echo "no_exist")
  echo "${check_image_status}"
}

