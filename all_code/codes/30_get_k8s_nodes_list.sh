#!/bin/bash
# *************************************
# 功能: 远程获取k8s集群节点列表，使用awk方式
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-04-30
# *************************************
 
linshi_file='/tmp/k8s_node.txt'  
host_file='/etc/hosts'

k8s_cluster_node_get(){
  ssh root@10.0.0.12 "kubectl get nodes" > ${linshi_file}
  k8s_cluster_node_get_update
}

k8s_cluster_node_get_update(){
  for i in $(awk 'NR>=2{print $1}' ${linshi_file});do
    ipaddr=$(grep "$i" "${host_file}" | awk '{print $1}')
    sed -i "/$i/s/$/&  $ipaddr/" ${linshi_file}
  done
}

k8s_cluster_node_list(){
  awk '
    function print_title(){
  	 printf "                           %25s\n","当前集群节点列表"
    }
    function print_line(){
  	 printf "-----------------------------------------------------------------------\n"
    }
    function print_header(){
  	 printf "|%4s|%25s|%19s|%10s|%10s|%10s|\n","序号","节点名称","节点地址","节点状态","软件版本","节点角色"
    }
    function print_body(arg1,arg2,arg3,arg4,arg5,arg6){
  	 printf "|%4s|%21s|%15s|%8s|%8s|%10s|\n",arg1,arg2,arg3,arg4,arg5,arg6
    }
    function print_end(arg1){
  	 printf "|k8s集群节点数量:   %-50s|\n",arg1
    }
    BEGIN{
      print_title();
      print_line();
      print_header();
      print_line();
      node_num=0
    } NR>=2,$1~"master"?type="控制节点":type="工作节点" {
      node_num+=1; 
      print_body(node_num,$1,$NF, $2, $(NF-1), type);
    }
    END{
      print_line();
      print_end(node_num);
      print_line();
    }
  ' ${linshi_file}
}

k8s_cluster_node_get
k8s_cluster_node_list
