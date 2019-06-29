#!/usr/bin/gnuplot

set terminal pngcairo nocrop enhanced font "verdana,13" size 800, 600

set output 'delayplot.png'

set xdata time
set timefmt "%S"
set xlabel "Time (mm:ss)"

set logscale y 10
set ylabel "Delay (s)"
set xtics nomirror rotate by -45

set grid
set autoscale

vars = "5 10 50 100"
plot for [var in vars] "delayms".var.".csv" \
	using ($1/1000):2 with lines lw 2 \
	title var." Variables" 
