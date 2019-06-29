#!/bin/zsh
for i in *(/)
do 
	HI=${i##flink_v}
	VARS=${HI%%_rf*}
	awk 'NR == 1 { zero = $1 } ;  \
		{ print $1 - zero " " $2 } ;' \
		< $i/delay.csv > delayms${VARS}.csv 
done
