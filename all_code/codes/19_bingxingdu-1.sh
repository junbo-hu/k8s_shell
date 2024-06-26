#!/bin/bash
# *************************************
# 功能: 循环间并行度控制
# 作者: 王树森
# 联系: wangshusen@sswang.com
# 版本: v0.1
# 日期: 2023-04-22
# *************************************
#!/bin/bash
# 设定并行度
degree=4
for i in $(seq 1 10)
do
    echo "num-"$i
    sleep 1 & # 提交到后台的任务
    # 阶段性完成任务
    [ $(expr $i % $degree) -eq 0 ] && wait
done

# 等待所有程序执行完毕
wait
