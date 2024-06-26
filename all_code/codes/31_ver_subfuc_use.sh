#!/bin/bash
# *************************************
# 功能: 子函数的local变量使用
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 微信群: 自学自讲—软件工程
# 抖音号: sswang_yys 
# 版本: v0.1
# 日期: 2024-05-08
# *************************************

child-1(){
  local age="18"
  echo "child-1-$name-$age"
  child-2
}
child-2(){
  local addr="bj"
  echo "child-2-$name-$age-$addr"
  child-3
}
child-3(){
  local xb="man"
  echo "child-3-$name-$age-$addr-$xb"
}
father(){
  local name="father"
  echo "fatherfunc-$name"
  child-1
  echo "fatherfunc-$name-$age"
}

father
