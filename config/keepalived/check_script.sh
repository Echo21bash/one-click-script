#!/bin/bash
#参数可执行程序
exe_file=""
#http地址
http_url=""
#tcp地址
tcp_url=""

if [[ -n "$exe_file" ]];then
        exe_process=`ps aux | grep $exe_file |grep -v grep | wc -l`
        if [[ $exe_process -eq 0 ]];then
                echo "$exe_file Is Not Runing,End."
                exit 2
        fi
fi


if [[ -n ${http_url} ]];then
        http_code=`curl -k -I -m 5 -o /dev/null -s -w %{http_code} ${http_url}`
        if [[ ${http_code} = '000' ]];then
                echo "${http_url} unreachable!!"
                exit 1
        fi

fi


if [[ -n ${tcp_url} ]];then
        tcp_status=`timeout 3 telnet ${tcp_url} 2>/dev/null | grep -o Connected | wc -l`

        if [[ ${tcp_status} = '0' ]];then
                echo "${tcp_url} cannot connect!!"
                exit 1

        fi

fi
