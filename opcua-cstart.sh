#!/bin/bash

set -e

SERVER_ADDRESS="192.168.10.2"
CLIENT="./opcua-client.py"

TMP=$(mktemp /tmp/opcuatest-XXXXX)

JOBMANAGER_CONTAINER=$(docker ps --filter name=jobmanager --format={{.ID}})
docker cp "build/libs/*-all.jar" "$JOBMANAGER_CONTAINER":/job.jar
docker exec "$JOBMANAGER_CONTAINER" flink run /job.jar $VARS 1>&2 &

# log system stats
collectl -P -f $TMP 1>&2 &
COLLECT_PID=$!

sleep 1

# start opcua2kafka client
${CLIENT} $1 $SERVER_ADDRESS $2 1>&2 &
CLIENT_PID=$!

wait $CLIENT_PID && kill $COLLECT_PID

rm $TMP

echo $TMP
