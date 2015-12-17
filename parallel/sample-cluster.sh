#!/bin/bash

SERVER_OUT='./server.out'
PYTHON='python' # this should be the command to python 2.7
OPENSMT=../opensmt
SERVER_DIR=./server
SERVER=${SERVER_DIR}/sserver.py
SERVER_COMMAND=${SERVER_DIR}/command.py
HEURISTIC=./clause_sharing/build/heuristic

# ----------------

trap '' HUP

function info {
  tput bold
  echo "$@"
  tput sgr0
}

function success {
	tput setaf 2
	info "$@"
}

function error {
	tput setaf 9
	info "$@"
}

function check {
    command -v $1 >/dev/null 2>&1
    return $?
}

function require {
    check $1 || { error "Missing program '$1'."; info $2; echo 'Aborting.' >&2; exit 1;}
}

function require_clauses {
    if ! (check redis-server || check ./deps/redis-server); then
        cd deps
        if [ ! -d "redis-stable" ]; then
            info -n 'Downloading REDIS... '
            require wget
            require tar
            wget http://download.redis.io/redis-stable.tar.gz
            tar xzf redis-stable.tar.gz
            rm redis-stable.tar.gz
            sussess 'done'
            cd redis-stable
            info 'Compiling REDIS... '
            make
            success 'done'
            cd ..
        fi
        require ./redis-stable/src/redis-server
        require ./redis-stable/src/redis-cli
        ln -s ./redis-stable/src/redis-cli ./redis-stable/src/redis-server .
        cd ..
    fi

    if (exec 9<>/dev/tcp/127.0.0.1/6379) &>/dev/null; then
        echo
        info -n 'TCP port 6379 is open for listening. '
        echo 'Assuming REDIS-SERVER already running'
        echo
    else
        info -n 'Starting REDIS-SERVER... '
        if check redis-server; then
            redis-server &>/dev/null &
        else
            ./deps/redis-server &>/dev/null &
        fi
        success 'done'
    fi
    exec 9>&-
    exec 9<&-

    if ! (check ${HEURISTIC}); then
        info 'Heuristic for clause sharing not found. Compiling...'
        make &>/dev/null
        success '... done'
    fi
    require ${HEURISTIC}

}

clauses=false
mode='_lookahead'
sbatch=false
timeout=1000
splits=2
cport=5000
wport=3000

show_help() {
	echo "Usage $0 [-r][-S][-b sbatch FILE][-t TIMEOUT=$timeout][-s SPLIT_NUMBER=$splits][-c CPORT=$cport][-w WPORT=$wport] FILE1.smt2 [FILE2.smt [...]]"
	echo
	echo "-r    : use clause sharing (default $clauses)"
	echo "-S    : use scattering (default $mode)"
	exit 0
}

while getopts "hrSb:t:s:c:w:" opt; do
	case "$opt" in
		h|\?)
            show_help
        	;;
        r)  clauses=true
            ;;
        b)  sbatch=$OPTARG
            ;;
		S)  mode='_scattering'
		    ;;
		n)	timeout=$OPTARG
       		;;
		s)	splits=$OPTARG
		    ;;
		c)	cport=$OPTARG
       		;;
		w)	wport=$OPTARG
		    ;;
	esac
done

shift $((OPTIND-1))

if [ $# -le 0 ]; then
    error '.smt2 file(s) missing!'
    show_help
    exit
fi

if [ ${sbatch} = false ]; then
    error 'you must specify a batch file'
    exit
fi

require ${PYTHON}
require ${OPENSMT} 'Please compile OpenSMT2'
require ${SERVER}
require ${SERVER_COMMAND}

echo
info '! PLEASE READ THE README FIRST !'
echo
echo "number of splits:             $splits"
echo "split mode:                   $mode"
echo "timeout:                      $timeout"
echo "cport:                        $cport"
echo "wport:                        $wport"
echo
if ${clauses}; then
    require_clauses
fi
echo "SERVER stdout will be redirected to $SERVER_OUT"
echo
echo -n 'starting server... '
if ${clauses}; then
    ${PYTHON} ${SERVER} -r ${HEURISTIC} -c ${cport} -w ${wport} -t ${timeout} -d -f ${SERVER_DIR}/${mode} -s ${splits} -o ${OPENSMT} > ${SERVER_OUT} 2>/dev/null &
else
    ${PYTHON} ${SERVER} -c ${cport} -w ${wport} -t ${timeout} -d -f ${SERVER_DIR}/${mode} -s ${splits} -o ${OPENSMT} > ${SERVER_OUT} 2>/dev/null &
fi
server_pid=$!
sleep 1
success 'done'
echo -n "starting batch "
sbatch ${sbatch}
success ' done'
echo -n 'sending the files to the server... '
${PYTHON} ${SERVER_COMMAND} 127.0.0.1 $@
success 'done'
echo -n 'waiting for all the problems to be solved... '
wait ${server_pid}
success 'done!'
info "The results are in $SERVER_OUT"
success 'bye'