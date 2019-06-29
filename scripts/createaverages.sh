#!/bin/bash
rm delayavg.csv
rm jitteravg.csv

for i in delayms*.csv
do 
	 a=${i#delayms} 
	 b=${a%.csv} 
	 avg=$(awk -e ' { i++; \
	 acc += $2 } ; \
	 END { print acc / i }' $i ) 

	 echo $b $avg >> delayavg.csv
done

for i in jitterms*.csv
do 
	 a=${i#jitterms} 
	 b=${a%.csv} 
	 avg=$(awk -e ' { i++ ; \
		 acc += $2 } \
		 END { print acc / i }' $i ) 

	 echo $b $avg >> jitteravg.csv
done
