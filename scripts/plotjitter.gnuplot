#!/usr/bin/gnuplot

set terminal pngcairo nocrop enhanced font "verdana,13" size 800, 600

set output 'jitterplot.png'

set xdata time
set timefmt "%S"
set xlabel "Time (mm:ss)"

set logscale y 10
set yrange [0.00001:10]
set ylabel "Jitter (s)"
set xtics nomirror rotate by -45

set grid
#set autoscale

vars = "5 10 50 100"
plot for [var in vars] "jitterms".var.".csv" \
	using ($1/1000):2 with lines lw 2 smooth acsplines \
	title var." Variables" 
