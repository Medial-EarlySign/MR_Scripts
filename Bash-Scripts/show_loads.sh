#!/bin/bash
MAX_NODES=5
_term() { 
	#Force kill:
	NOT_END=$(ps -ef | grep get_cpu| grep -v grep | wc -l)
	if [ $NOT_END -gt 0 ]; then
		ps -ef | grep get_cpu | grep -v grep | awk '{print $2}' | xargs kill 2>&1 > /dev/null
	fi
	echo "Caught INT signal!" 
}

trap _term INT

echo "Utilization in all nodes (ctrl+C) to exit:"
for(( i=1; i<=$MAX_NODES; i++ ))
do
	echo ""
done

printf "\033[${MAX_NODES}A"
for(( i=1; i<=$MAX_NODES; i++ ))
do
  ssh -x node-0$i 'iter=0; while [ $iter -lt 50 ] ; do x=`/server/UsersData/${USER%-*}/MR/Projects/Scripts/Bash-Scripts/get_cpu.sh`; y=$(/server/UsersData/${USER%-*}/MR/Projects/Scripts/Bash-Scripts/get_mem.sh); x=`printf "%.1f%%" $x`; y=`printf "%.1f%%" $y`; z=$(date +"%H:%M:%S"); printf "\033[s\033[$(((${HOSTNAME:6:1})))B%s CPU:%8s     Mem:%8s     Update_Time:%s\033[u" $HOSTNAME ${x} ${y} ${z}; iter=$[$iter+1]; done' &
done
wait

for(( i=1; i<=$MAX_NODES; i++ ))
do
	echo ""
done

echo -e "\nDone"
