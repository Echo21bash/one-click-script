#!/bin/sh
cmd=$1
if [[ $cmd = fdfs_trackerd ]];then
  /opt/fastdfs/bin/fdfs_trackerd /opt/fastdfs/etc/tracker.conf start
elif [[ $cmd = fdfs_storaged ]];then
  /opt/fastdfs/bin/fdfs_storaged /opt/fastdfs/etc/storage.conf start
elif [[ $cmd = fdhtd ]];then
  /opt/fastdfs/bin/fdhtd /opt/fastdfs/etc/fdhtd.conf start
else
	echo 'Unknown command'
fi
