#!/bin/bash

USER=admin
PASSWORD=admin
SERVER=TODO
STARTDATE=$1
FINISHDATE=$2
shift 2

wget -q --user=$USER --password=$PASSWORD -O clusteresutilization.csv "$SERVER/api/v7/timeseries?query=select stats(utilization_across_disks, avg) where category = CLUSTER&contentType=text/csv&from=$STARTDATE&to=$FINISHDATE&desiredRollup=RAW"
wget -q --user=$USER --password=$PASSWORD -O clustercpuusage.csv "$SERVER/api/v7/timeseries?query=select stats(cpu_percent_across_hosts,avg) where category = CLUSTER&contentType=text/csv&from=$STARTDATE&to=$FINISHDATE&desiredRollup=RAW"

gnuplot << EOF
set title "CPU & Disk usage during a WordCount MapReduce execution (4 nodes, 50 Gb bigfile.txt)"
set terminal "png" size 800,500
set output "cluster.png"
set datafile separator ','
set xlabel "Time (hh:mm)"
set ylabel "Percentage (%)"
set xtics format "%H:%M"
set xdata time
set yrange [0:100]
set grid x y
plot "clusteresutilization.csv" using (\$0*60):4 w l lt rgb "#FF0000" title 'Disk usage', "clustercpuusage.csv" using (\$0*60):4 w l lt rgb "#0000FF" title 'CPU Usage'
EOF

commonglobalplot="set terminal pngcairo dashed size 800,500
set datafile separator ','
set xlabel \"Time (hh:mm)\"
set ylabel \"Percentage (%)\"
set xtics format \"%H:%M\"
set xdata time
set yrange [0:100]
set xtics nomirror
set grid x y

set style line 1 linetype 2 linecolor rgb \"black\"
set style line 2 linetype 1 linecolor rgb \"black\"
set style line 3 linetype 1 linecolor rgb \"blue\"
set style line 4 linetype 1 linecolor rgb \"red\"
set style line 5 linetype 1 linecolor rgb \"yellow\"
set style line 6 linetype 1 linecolor rgb \"brown\"
set style line 7 linetype 1 linecolor rgb \"cyan\""

commonglobalesutilizationplot="
set title \"Disk usage during a WordCount MapReduce execution ($# nodes, 50 Gb bigfile.txt)\"
set output \"mrglobalesutilization$#.png\"

plot \"clusteresutilization.csv\" using (\$0*60):4 ls 1 w l title 'Avg Disk utilization cluster',"

commonglobalcpuusageplot="
set title \"CPU usage during a WordCount MapReduce execution ($# nodes, 50 Gb bigfile.txt)\"
set output \"mrglobalcpuusage$#.png\"

plot \"clustercpuusage.csv\" using (\$0*60):4 ls 1 w l title 'Avg CPU usage cluster',"

for ((i=1;i<=$#;i++))
do
	nodename=${!i};
	cpuusage_filename=$nodename."cpuusage.csv";
	esutilization_filename=$nodename."esutilization.csv";
	style=$(( $i+1 ));

	wget -q --user=$USER --password=$PASSWORD -O $esutilization_filename $CPU "$SERVER/api/v7/timeseries?query=select utilization where category = disk and hostname=$nodename and logicalPartition = false&contentType=text/csv&from=$STARTDATE&to=$FINISHDATE&desiredRollup=RAW"
	wget -q --user=$USER --password=$PASSWORD -O $cpuusage_filename $CPU "$SERVER/api/v7/timeseries?query=select cpu_user_rate / getHostFact(numCores, 1) * 100 %2B cpu_system_rate / getHostFact(numCores, 1) * 100 where hostname=$nodename&contentType=text/csv&from=$STARTDATE&to=$FINISHDATE&desiredRollup=RAW"
	esplot=$esplot"\"$esutilization_filename\" using (\$0*60):4 ls $style w l title 'Disk utilization S$i'";
	cpuplot=$cpuplot"\"$cpuusage_filename\" using (\$0*60):4 ls $style w l title 'CPU usage S$i'";

	if [ $i != $# ]; then
		esplot=$esplot",";
		cpuplot=$cpuplot",";
	fi
done

gnuplot << EOF
$commonglobalplot$commonglobalesutilizationplot$esplot
EOF

gnuplot << EOF
$commonglobalplot$commonglobalcpuusageplot$cpuplot
EOF
