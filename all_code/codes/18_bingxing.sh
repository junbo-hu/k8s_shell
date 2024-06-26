#!/bin/bash
# *************************************
# 功能: Shell脚本模板
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-04-22
# *************************************
#!/bin/bash
# 定义起始时间
start_time=$(date +%s)

# 定义业务逻辑
for ((i=1; i<=20; i++ ))
do
  # 使用{}代表代码块，使用&放到后端执行
  {
  sleep 1
  echo "num-$i"
  }&
done

# wait 等待所有程序执行完毕
wait

# 定义结束时间
stop_time=$(date +%s)

# 获取程序执行时间
echo "程序执行: $(expr $stop_time - $start_time)"

