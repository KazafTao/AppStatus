#!/bin/bash

HOME_DIR="/root/myscripts/program"
CONFIG_FIEL="process.cfg"


#$1为需要获取的process.cfg的项
function get_items
{
	#查找GROUP_LIST下的所有组
	#tr将回车改成tab键
	LIST=`sed -n "/\[$1\]/,/\[.*\]/p" $CONFIG_FIEL | egrep -v "(^$|\[.*\])" | tr "\n" "\t"`
	#返回组列表的字符串
	echo "$LIST"
}

#返回process.cfg中所有组名，如DB,WEB...
function get_all_group
{
	get_items GROUP_LIST
}

#返回process.cfg中所有进程名，如nginx,mysql...
function get_all_process
{
        for group in `get_all_group`
        do
                echo `get_all_process_by_group $group`
        done
}

#$1为进程名,返回某个进程的pid
function get_process_pid_by_name
{
	if [ $# -ne 1 ];then
		return 1
	else
		pids=`ps -ef | grep $1 | egrep -v "(grep|$0)" | awk '{print $2}'`
		echo $pids
	fi

}

#$1为进程pid，返回某个进程的信息，包括运行状态，cpu,内存占用率和启动时间
function get_process_info_by_pid
{
	if [ `ps -ef | awk -v pid=$1 '$2==pid{print $0}' | wc -l` -eq 1 ];then
		process_status="Running"
		process_cpu=`ps aux | awk -v pid=$1 '$2==pid{print $3}'`
	        process_men=`ps aux | awk -v pid=$1 '$2==pid{print $4}'`
        	process_start_time=`ps -p $1 -o lstart | grep -v STARTED`

	else
		process_status="Stopped"
		process_cpu="Null"
                process_men="Null"
                process_start_time="Null"
	fi
}

#$1为进程名，返回该进程所在的组名
function get_group_by_process_name
{
	for group_name in `get_all_group`
	do
		for process_name in `get_all_process_by_group $group_name`
		do
			if [ $1 == $process_name ];then
				echo $group_name
			fi
		done
	done
}

#$1为想查询是否在process.cfg组中的组名，判断组名是否在process.cfg中
function is_group_in_config
{
	for group in `get_all_group`
	do
		if [ $1 == $group ];then
			return 0
		fi
	done
	echo "Group $1 is not in process.cfg"
	return 1
}

#$1为想查询是否在process.cfg组中的进程名，判断进程名是否在process.cfg中
function is_process_in_config
{
	for process in `get_all_process`
	do
		if [ $1 == $process ];then
			return
		fi
	done
	echo "Process $1 is not in process.cfg"
	return 1
}

#$1为组名，返回某个组的所有进程名
function get_all_process_by_group
{
	is_group_in_config $1
        if [ $? -eq 0 ];then
		get_items $1
	else
		echo "$1 is not in process.cfg"
        fi
}

#$1为进程名，$2为进程所在的组名称，返回格式化输出的字符串
function format_print
{
	ps -ef | grep $1 | egrep -v "(grep|$0)" &> /dev/null
	if [ $? -eq 0 ];then
		process_pids=`get_process_pid_by_name $1`
		for pid in $process_pids
        	do
			get_process_info_by_pid $pid
			awk -v process_name=$1 \
			    -v group_name=$2 \
			    -v pid=$pid \
			    -v process_status=$process_status \
			    -v process_cpu=$process_cpu \
			    -v process_men=$process_men \
			    -v process_start_time="$process_start_time" \
			    'BEGIN{printf "%-22s%-15s%-12s%-15s%-12s%-12s%-20s\n",process_name,group_name,pid,process_status,process_cpu,process_men,process_start_time}'
        	done
	else
		get_process_info_by_pid "Null"
                        awk -v process_name=$1 \
                            -v group_name=$2 \
                            -v pid="Null" \
                            -v process_status=$process_status \
                            -v process_cpu=$process_cpu \
                            -v process_men=$process_men \
                            -v process_start_time="$process_start_time" \
			    'BEGIN{printf "%-22s%-15s%-12s%-15s%-12s%-12s%-20s\n",process_name,group_name,pid,process_status,process_cpu,process_men,process_start_time}'
	fi
}

function main
{
	if [ ! -e $HOME_DIR/$CONFIG_FIEL ];then
                echo "$CONFIG_FIEL不存在"
                exit 1
	fi
	if [ $# -gt 0 ];then
		if [ $1 == "-g" ];then
			#移除"-g"
			shift
			awk 'BEGIN{printf "%-22s%-15s%-12s%-15s%-12s%-12s%-20s\n","ProcessName-----------","GroupName------","Pid---------","Status---------","CPU---------","Memory------","StartTime-----------"}'
			#遍历剩下所有的group name
			for group_name in $@
			do
				is_group_in_config $group_name || continue
				for process_name in `get_all_process_by_group $group_name`
				do
					#格式化输出
					is_process_in_config $process_name && format_print $process_name $group_name
				done
			done
		else
			awk 'BEGIN{printf "%-22s%-15s%-12s%-15s%-12s%-12s%-20s\n","ProcessName-----------","GroupName------","Pid---------","Status---------","CPU---------","Memory------","StartTime-----------"}'
			#格式化输出某个进程
			for process_name in $@
			do
				group_name=`get_group_by_process_name $process_name`
				is_process_in_config $process_name && format_print $process_name $group_name
			done
		fi
	else
		awk 'BEGIN{printf "%-22s%-15s%-12s%-15s%-12s%-12s%-20s\n","ProcessName-----------","GroupName------","Pid---------","Status---------","CPU---------","Memory------","StartTime-----------"}'
		for process_name in `get_all_process`
		do
			group_name=`get_group_by_process_name $process_name`
			is_process_in_config $process_name && format_print $process_name $group_name
		done
	fi
}

main $@