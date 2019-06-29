#!/bin/bash

set -e
VARS=(    5       10      50      100)
RFR_RATE=(0.005   0.01    0.1     0.2)
RQS_RATE=(100     100     100     100)
RUN_TIME=1800

rm -f var_counting

#recompile, just in case
gradle clean build jar

for j in `seq 0 $(( ${#VARS[@]} - 1 ))`
do
	i=${VARS[$j]}
	r=${RFR_RATE[$j]}
	s=${RQS_RATE[$j]}

	echo -e `date` - "var \t $i rfr \t $r \t rqs $s"
	if ! ./start_test.sh $i $r $s $RUN_TIME
	then echo try again
		./start_test.sh $i $r $s $RUN_TIME
	fi
done

mv var_counting var_counting_`date +%y%m%d`.csv

