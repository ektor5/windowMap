#!/bin/bash

set -e
#set -x

SERVER="opcua-server.py"
CLIENT="opcua-client.py"
CSTART="opcua-cstart.sh"

SERVER_PATH="/home/uddeholm"
RESULTDIR="results"

#SERVER_ADDRESS="uddeholm@uddeholm2-udoo-x86.local"
#CLIENT_ADDRESS="uddeholm@uddeholm-udoo-x86.local"
SERVER_ADDRESS="uddeholm@192.168.10.2"
CLIENT_ADDRESS="uddeholm@192.168.0.104"

VARS=$1
RFR_RATE=$2
RQS_RATE=$3
RUN_TIME=$4

log() {
  # args: string
  local COLOR=${GREEN}${BOLD}
  local MOD="-e"

  case $1 in
    err) COLOR=${RED}${BOLD}
      shift ;;
    pre) MOD+="n"
      shift ;;
    fat) COLOR=${RED}${BOLD}
      shift ;;
    *) ;;
  esac

  echo $MOD "${COLOR}${*}${RST}"
}

remote () {
	kill -0 $SERVER_PID 
	if (( $# ))
	then
		cat <<< "$@" > $S_FIFO ;
	else
		cat > $S_FIFO
	fi
}

remote_end () {
    #disable clean
    remote trap - INT EXIT QUIT ABRT TERM

    if (( $# ))
    then
	    remote "$@"
    else
	    cat | remote
    fi

    #close file descriptor, closes ssh connection
    exec 8>&-
}

close(){
	remote trap - INT EXIT QUIT ABRT TERM
	log "Cleaning... "
	if (( KAFKA ))
	then
		#stop kafka
		docker-compose down
	fi

	if (( OPCUA ))
	then 
		#kill remote
		remote_end 'kill -INT $SPID'
	else
		remote_end
	fi
	
	if [ -e "$S_FIFO" ]
	then
		rm "$S_FIFO"
	fi

	exit 0
}

#Upload
log "Uploading new version"
scp $SERVER ${SERVER_ADDRESS}:${SERVER_PATH}/

#start server
S_LOG="server.log"
S_FIFO="$(mktemp -u /tmp/fifo_tty-XXXXXX)"
mkfifo $S_FIFO

log "Starting serverconn"
ssh $SERVER_ADDRESS < $S_FIFO > $S_LOG 2>&1 &
SERVER_PID=$!

#keep fifo open
exec 8> $S_FIFO

#set remote clean
remote <<-LOL
		clean () {
			echo cleaning... ;
			kill -0 \$SPID && kill -INT \$SPID;
			cd ;
		} ;
	LOL
remote trap clean INT EXIT QUIT ABRT TERM

trap close INT ERR

log "Starting containers"
#start kafka
docker-compose up -d
KAFKA=1

JOBMANAGER_CONTAINER=$(docker ps --filter name=jobmanager --format={{.ID}})
KAFKA_CONTAINER=$(docker ps --filter name=kafka --format={{.ID}})
docker cp build/libs/my-app-1.8-SNAPSHOT-all.jar "$JOBMANAGER_CONTAINER":/job.jar
docker exec -t -i "$JOBMANAGER_CONTAINER" flink run -d /job.jar $VARS 

log "Starting opcua server"
#start opcua server
remote ${SERVER_PATH}/$SERVER $VARS $RFR_RATE \&
remote 'SPID=$!'
OPCUA=1

sleep 15

if [ ! -x /proc/$SERVER_PID ]
then
	log err "server aborted"
	exit 1
fi

#start client
log "Starting client"
TMP=$(./$CSTART $RQS_RATE $RUN_TIME $VARS)

if [ -z "$TMP" ]
then
	log err "error: TMP not valid"
	exit 1
fi

log "Downloading results..."
if [ ! -d "$RESULTDIR" ]
then
	mkdir -p ${RESULTDIR}
fi

DATE=$(date +%FT%H%M)
TESTDIR="$RESULTDIR/flink_v${VARS}_rf${RFR_RATE}_rq${RQS_RATE}_t${RUN_TIME}_${DATE}"
mkdir -p "$TESTDIR"

mv ${TMP}*.gz "$TESTDIR/"
#mv ${TMP}_stream.log "$TESTDIR/"
#mv ${TMP}.csv "$RESULTDIR/opcua_v${VARS}_rf${RFR_RATE}_rq${RQS_RATE}_t${RUN_TIME}.csv"
#mv ${TMP}.pcap "$RESULTDIR/opcua_v${VARS}_rf${RFR_RATE}_rq${RQS_RATE}_t${RUN_TIME}.pcap"

docker logs $JOBMANAGER_CONTAINER > "$TESTDIR/flink.log"
docker logs $KAFKA_CONTAINER > "$TESTDIR/kafka.log"
kafkacat -C -e -b kafka -t MyVariable0flinked -f '%T %s \n' > "$TESTDIR/delay.csv"

sleep 1
COUNT=$(ssh $SERVER_ADDRESS cat /tmp/opcua-counting)
log "count $COUNT"
echo ${VARS} ${RFR_RATE} ${RQS_RATE} $COUNT >> var_counting

log "Done. Killing server..."
close
