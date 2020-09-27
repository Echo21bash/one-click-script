#!/bin/bash

export HISTTIMEFORMAT="[%Y-%m-%d %H:%M:%S] [`who am i 2>/dev/null| awk '{print $NF}'|sed -e 's/[()]//g'`] "
export PROMPT_COMMAND='\
  if [ -z "$OLD_PWD" ];then
        export OLD_PWD=$(pwd);
  fi;
  if [ ! -z "$LAST_CMD" ] && [ "$(history 1)" != "$LAST_CMD" ]; then
        echo  `whoami`_shell_cmd "[$OLD_PWD]$(history 1)" >>/var/log/bash_history.log;
  fi ;
  export LAST_CMD="$(history 1)";
  export OLD_PWD=$(pwd);'
