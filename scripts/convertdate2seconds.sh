#!/bin/zsh
for i in *(/); 
do
	name=$(basename $i/*.tab.gz)
	vars=${i%%_rf*}
	zcat $i/*.tab.gz | while read date time stuff
	do 
		if [[ "$date" =~ "#" ]]
		then 
			continue
		fi
		echo $(date --date="$date $time" +%s) $stuff 
	done | awk -e 'NR == 1 { zero = $1 } ; { print $1 - zero " " $10 " " $18 " " $19 " " $20 } ;' > \
		cpu-$vars.tabs
done
