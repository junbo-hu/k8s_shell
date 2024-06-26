#!/bin/bash
# *************************************
# 功能: 通过文件描述符来实现消息队列的效果
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-04-22
# *************************************
# 定义起始时间
start_time=$(date +%s)
# 定义并行度的值
degree="$1"

# 定义阻塞描述符
[ -e /tmp/fd_test ] || mkfifo /tmp/fd_test  	# 创建管道
exec 3<>/tmp/fd_test  # 将文件描述符3写入 FIFO 管道
rm -rf /tmp/fd_test      # 记住文件描述符特征后，文件就不用了

# 设置并行度为2，代表阻塞的频率
for ((i=1; i<=${degree}; i++))
do
  echo >&3 	              # &3 代表引用文件描述符
done

# 定义业务逻辑
for ((i=1; i<=20; i++ ))
do
  read -u3  # 从阻塞管道中提取信息
  # 使用{}代表代码块，使用&放到后端执行
  {
  sleep 1
  echo "num-$i"
  echo >&3  # 命令执行完毕后，把信息放回阻塞管道
  }&
done

# wait 等待所有程序执行完毕
wait

# 定义结束时间
stop_time=$(date +%s)

# 获取程序执行时间
echo "程序执行: $(expr $stop_time - $start_time)"
echo <&3-  # 关闭文件描述符的读
echo >&3-  # 关闭文件描述符的写
