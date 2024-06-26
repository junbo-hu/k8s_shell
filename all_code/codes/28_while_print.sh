#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-04-23
# *************************************
 #  local msg=$(curl -s "${harbor_url}/${harbor_ver}")
 #  local ver=$(echo "${msg}" | jq -r ".version")
while_print(){
  local ver='v2.1'
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
        # ssh ${login_user}@${harbor_addr} "systemctl restart harbor"
        break
      fi
      # msg=$(curl -s "${harbor_url}/${harbor_ver}")
      # ver=$(echo "${msg}" | jq -r ".version")
    done
    let num+=1
  done
}

while_print
