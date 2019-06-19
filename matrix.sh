#!/bin/bash

set -e
VARS=(    5       10      25      50)
RFR_RATE=(0.01    0.02	  0.05    0.1  )
RQS_RATE=(100     100     100     100)
RUN_TIME=60

rm -f var_counting

#recompile, just in case
gradle clean build jar

for j in `seq ${#VARS[@]}`
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

