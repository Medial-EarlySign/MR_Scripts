#!/bin/bash
sig_name=${1-DIAGNOSIS}
repository=${2-/data/Repositories/maccabi_may2019/maccabi.repository}
output_dir=${3-DEFAULT}

if [ $output_dir == "DEFAULT" ]; then
	output_dir=${repository%/*}
fi

echo "Run count on signal ${sig_name} for repository: ${repository} output to: ${output_dir}"

echo -e "CODE_ID\tDESCRIPTION\tTOTAL_COUNT\tPID_COUNT" > ${output_dir}/${sig_name}_Hist.txt
Flow --rep ${repository} --pids_sigs_print --sigs ${sig_name} | awk '{ code=substr($6,0, index($6, "|") - 1); d[code]+=1; d_pids[code][$1]=1; m[code] = substr($6, index($6, "|")+1)  } END { for (i in d) { print i, m[i], d[i], length(d_pids[i]) } }' OFS="\t" >> ${output_dir}/${sig_name}_Hist.txt