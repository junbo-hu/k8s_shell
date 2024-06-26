#!/bin/bash
# *************************************
# 功能: 远程获取k8s集群节点列表，使用awk方式
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2024-04-30
# *************************************
 
host_file='/etc/hosts'


k8s_cluster_node_list(){
  awk '
    function print_title(){
  	 printf "                           %25s\n","当前集群节点列表"
    }
    function print_line(){
  	 printf "-----------------------------------------------------------------------\n"
    }
    function print_header(){
  	 printf "|%4s|%35s|%24s|%15s|\n","序号","节点名称","节点缩写","节点地址"
    }
    function print_body(arg1,arg2,arg3,arg4){
  	 printf "|%4s|%31s|%20s|%11s|\n",arg1,arg2,arg3,arg4
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
    } $2~"kube" {
      node_num+=1; 
      print_body(node_num,$2,$NF, $1);
    }
    END{
      print_line();
      print_end(node_num);
      print_line();
    }
  ' ${host_file}
}

k8s_cluster_node_list
