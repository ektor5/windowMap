#!/bin/bash

set -e

VARS=(    1       5      10    50   100    500  1000)
RFR_RATE=(0.0001  0.001  0.01  0.1  1)
RQS_RATE=(1       5     10   100  1000)
RUN_TIME=60

rm -f var_counting

for i in ${VARS[@]}
do
	for r in ${RFR_RATE[@]}
	do

		for s in ${RQS_RATE[@]}
		do
			echo -e `date` - "var \t $i rfr \t $r \t rqs $s"
			if ! ./start_test.sh $i $r $s $RUN_TIME
			then echo try again
				./start_test.sh $i $r $s $RUN_TIME
			fi
		done
		
	done
	
done

mv var_counting var_counting_`date +%y%m%d`.csv

