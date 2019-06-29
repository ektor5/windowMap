#!/usr/bin/gnuplot

set terminal pngcairo nocrop enhanced font "verdana,13" size 800, 600

set output 'loadplot.png'

set xdata time
set timefmt "%s"
set xlabel "Time (mm:ss)"

set ylabel "Load (# processes)"
set xtics nomirror rotate by -45

set grid
set autoscale

vars = "5 10 50 100"
plot for [var in vars] "cpu-flink_v".var.".tabs" \
	using 1:5 with lines lw 2 smooth acsplines \
	title var." Variables" 
