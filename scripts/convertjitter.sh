#!/bin/zsh
for i in *(/)
do 
	HI=${i##flink_v}
	VARS=${HI%%_rf*}
	awk 'NR == 500 { zero = $1; last = $2 } ;  \
		NR > 500 { jit = ($2 - last) ; j = (jit > 0)?jit:-jit ; print $1 - zero " " j ; last = $2 } ;' \
		< $i/delay.csv > jitterms${VARS}.csv 
done
