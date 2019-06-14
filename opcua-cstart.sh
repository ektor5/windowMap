#!/bin/bash

set -e

SERVER_ADDRESS="192.168.10.2"
CLIENT="./opcua-client.py"
STREAM="mvn exec:java -D exec.mainClass=com.mycompany.app.App -Dexec.args=$3"

TMP=$(mktemp /tmp/opcuatest-XXXXX)

# log system stats
collectl -P -f $TMP 1>&2 &
COLLECT_PID=$!

# start Flink streaming job
${STREAM} 1>&2 > ${TMP}_stream.log &
STREAM_PID=$!

sleep 1

# start opcua2kafka client
${CLIENT} $1 $SERVER_ADDRESS /tmp/client-tmp 1>&2 &
CLIENT_PID=$!

wait $CLIENT_PID && kill -INT $STREAM_PID && kill $COLLECT_PID

rm $TMP

echo $TMP
