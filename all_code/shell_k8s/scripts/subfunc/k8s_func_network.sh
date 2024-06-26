#!/bin/bash
# *************************************
# 功能: 网络解决方案的功能函数库
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-04-22
# *************************************

# 检测下载文件是否正常
k8s_cluster_network_yaml_wget_check(){
  # 获取参数
  local path_to_file="$1"
  
  # 检测文件逻辑
  file_size=$(ls -l "${path_to_file}" |awk '{print $5}')
  if [ "${file_size}" -ne 0 ]; then
    local file_status="normal"
  else
    local file_status="abnormal"
  fi
  echo "${file_status}"
}

# 检测本地配置文件是否存在函数
k8s_cluster_network_yaml_get(){
  # 获取参数
  local path_to_file="$1"
  local url_to_file="$2"
  local file_name=$(basename ${path_to_file})

  # 功能逻辑
  if [ -f "${path_to_file}" ]; then
    echo -e "\e[32m${file_name} 已存在，无需重复获取!!!\e[0m"
  else
    # 
    local wget_num=0
    while [ "${wget_num}" -lt 3 ]; do
      # 下载文件
      wget --timeout=3 --waitretry=2 --tries=3 "${url_to_file}" -O "${path_to_file}-bak"
      # 检测文件是否下载成功
      local file_status=$(k8s_cluster_network_yaml_wget_check "${path_to_file}-bak")
      if [ "${file_status}" != "normal" ]; then
        sleep 3
      else
        break
      fi
      let wget_num+=1
    done
    # 防止修改失误，做文件备份
    cp "${path_to_file}-bak" "${path_to_file}"
    echo -e "\e[32m${file_name} 已下载成功，可以正常使用!!!\e[0m"
  fi
}

# 定制flannel网络清单文件函数
k8s_cluster_network_flannel_yaml_conf(){
  # 获取参数
  local local_path_to_file="$1"
  local yaml_image_repo="docker.io/flannel"
  local yaml_image_harbor="${harbor_addr}/${harbor_k8s_repo}"

  # 修改配置文件
  sed -i "s#${yaml_image_repo}#${yaml_image_harbor}#g" ${local_path_to_file}
  
}

# 定制calico网络清单文件函数
k8s_cluster_network_calico_yaml_conf(){
  # 获取参数
  local local_path_to_file="$1"
  local yaml_image_repo="docker.io/calico"
  local yaml_image_harbor="${harbor_addr}/${harbor_k8s_repo}"

  # 修改配置文件
  sed -i 's#"type": "calico-ipam"#"type": "host-local",\
              "subnet": "usePodCidr"#' "${local_path_to_file}"
  sed -i '/CALICO_DISABLE_FILE_LOGGING/i \
            - name: CALICO_IPV4POOL_CIDR \
              value: "K8S_POD_CIDR_DEFINE" \
            - name: CALICO_IPV4POOL_BLOCK_SIZE \
              value: "24" \
            - name: USE_POD_CIDR \
              value: "true" \
            - name: IP_AUTODETECTION_METHOD \
              value: interface=K8S_NODE_NET_DEV' "${local_path_to_file}"
  sed -i "s#K8S_POD_CIDR_DEFINE#${K8S_POD_CIDR_DEFINE}#" "${local_path_to_file}"
  sed -i "s#K8S_NODE_NET_DEV#${K8S_NODE_NET_DEV}#" "${local_path_to_file}"

  # 修改镜像文件
  sed -i "s#${yaml_image_repo}#${yaml_image_harbor}#g" ${local_path_to_file}

}

# 定制网络清单文件属性函数
k8s_cluster_network_yaml_conf(){
  # 获取参数
  local k8s_cluster_network_type="$1"
  local local_path_to_file="$2"
  # 根据网络类型定制yaml清单文件
  case "${k8s_cluster_network_type}" in
    "flannel")
      k8s_cluster_network_flannel_yaml_conf "${local_path_to_file}";;
    "calico")
      k8s_cluster_network_calico_yaml_conf "${local_path_to_file}";;
    "cilium")
      echo "定制cilium配置";;
    *)
      echo "k8s项目暂不支持 ${k8s_cluster_network_type} 方案，请使用如下几种网络解决方案"
      echo "Flannel、Calico、Cilium";;     
  esac
}

# 传递网络配置文件到远程主机
k8s_cluster_network_yaml_scp(){
  # 接收参数
  local local_path_to_file="$1"
  local remote_path_to_file="$2"
  local remote_file=$(basename ${remote_path_to_file})
  local remote_dir=$(dirname ${remote_path_to_file})
   
  # 定制文件传输逻辑
  ssh "${login_user}@${master1}" "[ ! -d ${remote_dir} ] && mkdir ${remote_dir} -p; \
         [ -f ${remote_path_to_file} ] && rm -f ${remote_path_to_file}"
  scp "${local_path_to_file}" "${login_user}@${master1}:${remote_dir}"
  echo -e "\e[32m${remote_file} 已传递到远程的master主机 ${remote_dir} 目录!!!\e[0m"
}

# 获取yaml文件所依赖的镜像函数
k8s_cluster_network_image_get(){
  # 接受参数
  local local_path_to_file="$1" 

  # 提交镜像之前，判断一下本地镜像仓库是否存在该镜像
  echo -e "\e[33m获取网络解决方案依赖镜像并提交到本地harbor镜像仓库!!!\e[0m"
  local network_image=$(grep ' image:' ${local_path_to_file} | uniq | awk '{print $NF}')
 
  
  # 获取镜像仓库镜像列表
  get_proj_image_list "${harbor_k8s_repo}"
  
  # 对比镜像文件信息
  for i in ${network_image}; do
    # 获取镜像名称信息
    local image_name=$(echo $i | awk -F '/' '{print $NF}')
    local image_new_name="${harbor_addr}/${harbor_k8s_repo}/${image_name}"

    # 判断harbor是否存在镜像文件
    local check_image_status=$(grep "${image_new_name}" "${harbor_images_list_file}" >>/dev/null 2>&1 \
                               && echo "存在" || echo "不存在")
    # 如果存在目标镜像文件，则跳过镜像的获取和提交
    if [ "${check_image_status}" == "存在" ]; then
      echo -e "\e[32m${image_new_name} 镜像文件在harbor镜像仓库已存在，不用重复获取!!!\e[0m"
      # 对于已存在的镜像，可以直接跳过，对下一项进行检测
      continue
    fi
    ssh "${login_user}@${master1}" "docker pull $i; \
         docker tag $i ${image_new_name}; \
         docker push ${image_new_name}; \
         docker rmi $i"
  done
}

# 远程执行网络解决方案的资源清单文件函数
k8s_cluster_network_yaml_apply(){
  # 获取参数
  local remote_path_to_file="$1"
  
  # 执行资源清单文件
  ssh "${login_user}@${master1}" "/usr/bin/kubectl apply -f ${remote_path_to_file}"
}

# 检测flannel网络环境
k8s_network_status_check(){
  # 获取参数
  local network_ns="$1"
  local network_ds_name="$2"
 
  # 获取集群的网络pod数量
  local check_num=0
  while [ "${check_num}" -lt 3 ];do
    # 尝试获取远程网络解决方案的网络状态
    local get_network_pod_num=$(ssh "${login_user}@${master1}" \
                        "kubectl get ds ${network_ds_name} -n ${network_ns} -o json" 2>/dev/null \
                        | jq ".status.numberReady")
    # 为了保证条件判断的成立，应该避免值为空
    [ -z "${get_network_pod_num}" ] && get_network_pod_num=0
    if [ ${get_network_pod_num} -gt 0 ];then
      local network_status="running"
      break
    else
      local network_status="notrun"
      let check_num+=1
      # 等待3秒后再次测试效果
      sleep 3
    fi
  done
  # 输出
  echo "${network_status}"
}

# 获取当前的节点网络状态函数
k8s_cluster_network_nodes_list(){
  # 信息显示
  echo -e "\e[33m\n正在检查当前集群的节点网络状态:"
  waiting 3
  echo_tag "=" 50
  ssh "${login_user}@${master1}" "/usr/bin/kubectl get nodes"
  echo_tag "=" 50
  echo -e "\e[0m"
}

# flannel网络环境清理后的检测函数
k8s_cluster_network_status_check(){
  # 获取参数
  local k8s_cluster_network_type="$1"
  local network_ns="$2"
  local network_ds_name="$3"

  # 获取当前的网络状态
  local current_network_status=$(k8s_network_status_check "${network_ns}" "${network_ds_name}")

  # 判断网络后续处理
  if [ "${current_network_status}" == "running" ]; then
    echo -e "\e[32m当前k8s集群 ${k8s_cluster_network_type} 网络解决方案部署成功!!!\e[0m"
  else
    echo -e "\e[31m当前k8s集群 ${k8s_cluster_network_type} 网络解决方案部署失败\e[0m"
    echo -e "\e[31mpod创建时间稍长，可能出现该提示，属于正常，请自行检查效果!!!\e[0m"
  fi
  k8s_cluster_network_nodes_list
}

# 检测k8s集群网络环境状态
k8s_cluster_network_install_status(){
  # 获取参数
  local k8s_cluster_network_type="$1"

  # 根据网络类型定制yaml清单文件
  case "${k8s_cluster_network_type}" in
    "flannel")
      k8s_cluster_network_status_check "${k8s_cluster_network_type}" \
                                         "${flannel_ns}" "${flannel_ds_name}";;
    "calico")
      k8s_cluster_network_status_check "${k8s_cluster_network_type}" \
                                         "${calico_ns}" "${calico_ds_name}";;
    "cilium")
      echo "定制cilium配置";;
    *)
      echo "k8s项目暂不支持 ${k8s_cluster_network_type} 方案，请使用如下几种网络解决方案"
      echo "Flannel、Calico、Cilium";;
  esac
}


# 定制网络解决方案安装逻辑函数
k8s_cluster_network_install_logic(){
  # 获取参数
  local k8s_cluster_network_type="$1"
  local local_path_to_file="$2"
  local url_to_file="$3"
  local remote_path_to_file="$4"
  
  # 1 获取配置清单文件
  k8s_cluster_network_yaml_get "${local_path_to_file}" "${url_to_file}"

  # 2 获取镜像文件
  k8s_cluster_network_image_get "${local_path_to_file}"

  # 3 定制网络解决方案配置文件
  k8s_cluster_network_yaml_conf "${k8s_cluster_network_type}" "${local_path_to_file}"

  # 4 将合适的文件模板传递到master主机
  k8s_cluster_network_yaml_scp "${local_path_to_file}" "${remote_path_to_file}"

  # 5 运行资源清单文件
  k8s_cluster_network_yaml_apply "${remote_path_to_file}"

  # 这里涉及到pod的启动，所以稍微等待一下 
  waiting 5

  # 6 检测网络解决方案效果
  k8s_cluster_network_install_status "${k8s_cluster_network_type}"
}

# 定制cilium解决方案
k8s_network_cilium(){
  echo "定制cilium网络..."
}

# 定制网络函数
k8s_network_install(){
  # 根据参数，选择不同的解决方案
  # 接收参数
  local net_type="$1"
  
  echo -e "\e[33m开始执行k8s集群定制网络解决方案操作!!!\e[0m"
  # 定制网络解决方案
  if [ "${net_type}" == "flannel"  ];then
    local current_flannel_status=$(k8s_network_status_check "${flannel_ns}" "${flannel_ds_name}")
    if [ "${current_flannel_status}" == "notrun" ]; then
      local local_path_to_file="${addons_flannel}/${flannel_yaml}"
      local url_to_file="${flannel_url}/${flannel_yaml}"
      local remote_path_to_file="${remote_dir}/flannel/${flannel_yaml}"
      k8s_cluster_network_install_logic "${net_type}" "${local_path_to_file}" \
                                        "${url_to_file}" "${remote_path_to_file}"
    else
      echo -e "\e[33mk8s集群flannel网络解决方案已运行，无需重复执行!!!\e[0m"
    fi
  elif [ "${net_type}" == "calico" ];then
    local current_calico_status=$(k8s_network_status_check "${calico_ns}" "${calico_ds_name}")
    if [ "${current_calico_status}" == "notrun" ]; then
      local local_path_to_file="${addons_calico}/${calico_yaml}"
      local url_to_file="${calico_url}"
      local remote_path_to_file="${remote_dir}/calico/${calico_yaml}"
      k8s_cluster_network_install_logic "${net_type}" "${local_path_to_file}" \
                                        "${url_to_file}" "${remote_path_to_file}"
    else
      echo -e "\e[33mk8s集群flannel网络解决方案已运行，无需重复执行!!!\e[0m"
    fi
    
  elif [ "${net_type}" == "cilium" ];then
    k8s_network_cilium
  else
    echo -e "\e[31m目前该脚本暂不支持其他类型的网络解决方案，有需求可以联系：\e[0m"
    echo -e "\e[31m   抖音号：sswang_yys, B站：自学自讲\n\e[0m"
  fi
  
  echo -e "\e[32m指定网络解决方案已经部署完毕!!!\n\e[0m"
}
