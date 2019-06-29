#!/usr/bin/gnuplot

set terminal pngcairo nocrop enhanced font "verdana,13" size 800, 600

set output 'jitterbox.png'

set xlabel "Variables"
set logscale y 10
set ylabel "Jitter (s)"

set autoscale
set grid

set style fill solid border -1
set boxwidth 0.6

unset key

vars = "5 10 50 100"
plot "jitteravg.csv" \
	every ::0 using ($0):2:($0+1):xticlabels(1) with boxes lc variable
