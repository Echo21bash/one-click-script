#!/bin/bash
#参数可执行程序
exe_file=$1
 if [ -n "$exe_file" ];then
        exe_process=`ps aux | grep $exe_file |grep -v grep | wc -l`
        if [ $exe_process -eq 0 ];then
                echo "$exe_file Is Not Runing,End."
                exit 1
        fi
 else
        echo "Check File Cant Be Empty!"
 fi
 