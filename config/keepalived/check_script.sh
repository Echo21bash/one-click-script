#!/bin/bash
#参数可执行程序
exe_file=
vip=192.168.31.100:6443
if [ -n "$exe_file" ];then
        exe_process=`ps aux | grep $exe_file |grep -v grep | wc -l`
        if [ $exe_process -eq 0 ];then
                echo "$exe_file Is Not Runing,End."
                exit 1
        fi
else
        echo "Check File Cant Be Empty!"
fi
if [ -n "$vip" ];then
        http_code=`curl -I -m 10 -o /dev/null -s -w %{http_code} ${vip}`

        if [ $http_code -ne 200 ];then
                echo "http_code Is $http_code,End."
                exit 1
        fi
else
        echo "Check vip Cant Be Empty!"
fi
