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
	kill -0 $SERVER_PID || error
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

	remote_end 'kill -INT $SPID'
	
	if [ -e "$S_FIFO" ]
	then
		rm "$S_FIFO"
	fi
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


remote ${SERVER_PATH}/$SERVER $VARS $RFR_RATE \&
remote 'SPID=$!'

trap close INT
sleep 10

if [ ! -x /proc/$SERVER_PID ]
then
	log err "server aborted"
	exit 1
fi

#start kafka
docker-compose up -d
KAFKA=1

sleep 5

#start client
log "Starting client"
TMP=$(./$CSTART $RQS_RATE $RUN_TIME $VARS)

log "Downloading results..."
if [ ! -d "$RESULTDIR" ]
then
	mkdir -p ${RESULTDIR}
fi


log "Done. Killing server..."
close

if [ -z "$TMP" ]
then
	log err "error: TMP not valid"
	exit 1
fi

DATE=$(date -Iminutes)
mv ${TMP}*.tab.gz "$RESULTDIR/flink_v${VARS}_rf${RFR_RATE}_rq${RQS_RATE}_t${RUN_TIME}_${DATE}.tab.gz"
mv ${TMP}_stream.log "$RESULTDIR/flink_v${VARS}_rf${RFR_RATE}_rq${RQS_RATE}_t${RUN_TIME}_${DATE}.tab.gz"
#mv ${TMP}.csv "$RESULTDIR/opcua_v${VARS}_rf${RFR_RATE}_rq${RQS_RATE}_t${RUN_TIME}.csv"
#mv ${TMP}.pcap "$RESULTDIR/opcua_v${VARS}_rf${RFR_RATE}_rq${RQS_RATE}_t${RUN_TIME}.pcap"

sleep 1
COUNT=$(ssh $SERVER_ADDRESS cat /tmp/opcua-counting)
log "count $COUNT"
echo ${VARS} ${RFR_RATE} ${RQS_RATE} $COUNT >> var_counting

exit 0
