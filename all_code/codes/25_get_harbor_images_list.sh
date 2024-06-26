#!/bin/bash
# *************************************
# 功能: 获取harbor所有镜像信息列表
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-01-10
# *************************************

# 获取项目
# curl http://10.0.0.20/api/v2.0/projects -s | jq '.[].name' | awk -F '"' '{print $2}'

# 获取镜像
# curl http://10.0.0.20/api/v2.0/search?q=google_containers -s | jq '.repository[].repository_name' | awk -F'"' '{print $2}'

# 获取标签
# curl http://10.0.0.20/api/v2.0/projects/google_containers/repositories/pause/artifacts -s | jq '.[].tags[].name' | awk -F'"' '{print $2}'

# 基础环境变量
harbor_addr='10.0.0.20'
api_url='api/v2.0'
project_api="${api_url}/projects"
image_api="${api_url}/search?q="


# 获取所有项目
> /tmp/harbor-image.txt

projects_list=$(curl http://${harbor_addr}/${project_api} -s | jq '.[].name' | awk -F '"' '{print $2}')
for project in ${projects_list}; do
  # 获取所有的镜像名称
  images_list=$(curl http://${harbor_addr}/${image_api}${project} -s | jq '.repository[].repository_name' | awk -F'"|/' '{print $3}')
  for image in ${images_list}; do
    # 获取指定镜像的标签
    tag_list=$(curl http://${harbor_addr}/${project_api}/${project}/repositories/${image}/artifacts -s | jq '.[].tags[].name' | awk -F'"' '{print $2}')
    for tag in ${tag_list}; do
      echo "${project}/${image}:${tag}" | tee -a /tmp/harbor-image.txt
    done
  done
done
