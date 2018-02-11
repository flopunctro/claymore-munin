#!/bin/bash
set -o pipefail

DEBUG=""

TMPDIR=/dev/shm

if [[ -z "$1" ]]; then
    echo "Usage: $0 <minerhost> [ output_format ]"
    exit 0
fi

miner=$1
outformat=$2
tmpfile=$TMPDIR/$miner.out

if getent hosts $miner >/dev/null; then
    [ -n "$DEBUG" ] && echo "DEBUG INFO: Host exists."
else
    echo "Host $miner does not exist. Exiting."
    exit 0
fi

# check for data freshness
fresh=""
if [[ -f $tmpfile ]]; then
    fileage=`/usr/bin/stat -c %Y $tmpfile`
    now=`/bin/date +%s`
    let diff=$now-$fileage
    if [ "$diff" -le "90" ]; then
	fresh="yes"
    fi
fi

if [[ -z "$fresh" ]]; then
    [ -n "$DEBUG" ] && echo "DEBUG INFO: data is not fresh, polling.\narpinging $miner..."
    /usr/sbin/arping -c 3 $miner -q
    retcode=$?

    if [[ "$retcode" -ne 0 ]]; then
	echo "Error: host $miner dead (no arping reply)."
	exit 2
    fi

    /usr/bin/wget -T 10 -q --post-data='{"id":0,"jsonrpc":"2.0","method":"miner_getstat1"}' -O - http://$miner:3333 | jq -r .result[0,1,2,3,6] >$tmpfile
    retcode=$?
    if [[ "$retcode" -ne 0 ]]; then
	echo "Error: wget could not connect to $miner."
	exit 2
    fi
else
    [ -n "$DEBUG" ] && echo "DEBUG INFO: data is fresh, reusing tmpfile."
fi

[ -n "$DEBUG" ] && (echo "============ DEBUG INFO: tmpfile follows. ========== "; cat $tmpfile; echo "============")

# parse the output
read version bla < <(sed -n '1 p' $tmpfile)
read uptime < <(sed -n '2 p' $tmpfile)
IFS=";"
read total_hr valid_shr rej_shr < <(sed -n '3 p' $tmpfile)
read -a gpu_hrs < <(sed -n '4 p' $tmpfile)
read -a tempfans < <(sed -n '5 p' $tmpfile)
IFS=" "

gpu_no=${#gpu_hrs[@]}

declare -a gpu_temps
declare -a gpu_fans
for (( i=0; i<$gpu_no; i++ )); do
    gpu_temps[$i]=${tempfans[2*$i]}
    gpu_fans[$i]=${tempfans[2*$i+1]}
done

if [ -n "$DEBUG" ]; then
    echo "================ DEBUG INFO BLOCK =================
    miner version is $version
    uptime is $uptime
    total hashrate is $total_hr, valid shares = $valid_shr, rejected shares = $rej_shr
    number of GPUs is $gpu_no
   hashrates are ${gpu_hrs[@]}
    temps  are   ${gpu_temps[@]}
   fanspeeds are ${gpu_fans[@]}
======================="
fi

uptime_hr=$((uptime/60))
uptime_min=$((uptime%60))

case "$outformat" in
    check)
	echo $total_hr
	;;
    graph)
	echo "uptime=$uptime_hr"
	let total_hr_abs=${total_hr}*1000
	echo "total_hr=$total_hr_abs"
	echo "gpu_no=$gpu_no"
	for (( i=0; i<$gpu_no; i++ )); do
	    let gpu_hr_abs=${gpu_hrs[$i]}*1000
	    echo "gpu_hr[$i]=$gpu_hr_abs"
	    echo "gpu_temp[$i]=${gpu_temps[$i]}"
	    echo "gpu_fan[$i]=${gpu_fans[$i]}"
	done
	;;
    *)
	echo "$miner: uptime: ${uptime_hr}h:${uptime_min}m, total hashrate: $total_hr"
	echo -e -n "GPUs:$gpu_no\t"
	for (( i=0; i<$gpu_no; i++ )); do
	    echo -e -n "GPU$i\t"
	done
	echo; echo -e -n "hshrte\t"
	for (( i=0; i<$gpu_no; i++ )); do
	    echo -e -n "${gpu_hrs[$i]}\t"
	done
	echo; echo -e -n "temp\t"
	for (( i=0; i<$gpu_no; i++ )); do
	    echo -e -n "${gpu_temps[$i]}\t"
	done
	echo; echo -e -n "fanspd\t"
	for (( i=0; i<$gpu_no; i++ )); do
	    echo -e -n "${gpu_fans[$i]}\t"
	done
	echo
	;;
esac

