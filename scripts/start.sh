#!/bin/bash
set -u
set -e

CURRENT_HOST_IP="$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || curl -s --retry 2 icanhazip.com)"
CONSTELLATION_PORT=9000

check_constellation_isStarted(){
    set +e
    RETVAL=""
    while [ "$RETVAL" == "" ]
    do
    
        RETVAL="$(ss -nutlp | grep $CONSTELLATION_PORT)"
        [ "$RETVAL" != "" ] && echo "[*] constellation node at $CONSTELLATION_PORT is now up."
        [ "$RETVAL" == "" ] && echo "[*] constellation node at $CONSTELLATION_PORT is still starting. Awaiting 5 seconds." && sleep 5

    done
    echo "[*] resuming start procedure"
    set -e
}

echo "Optional use for a clean start: start clean"

if ( [ ! $# -ne 1 ] && [ "clean" == "$1" ]); then 
    
    echo "Cleaning your node ..."
    #Backup directory tree
    rm -rf ~/alastria/logs/quorum_*
    rm -rf ~/alastria/data/geth/chainData
    rm -rf ~/alastria/data/geth/nodes
    # Optional in case you start with process locked
    # rm ~/alastria/data/geth/LOCK
    rm -f ~/alastria/data/geth/transactions.rlp
    rm -f ~/alastria/data/geth.ipc
    #rm -f ~/alastria/data/quorum-raft-state
    #rm -f ~/alastria/data/raft-snap
    #rm -f ~/alastria/data/raft-wal
    rm -rf ~/alastria/data/constellation/data
    rm -f ~/alastria/data/constellation/constellation.ipc
    rm -rf ~/alastria/data/geth/lightchaindata
    rm -rf ~/alastria/data/geth/chaindata
fi

NETID=82584648528
mapfile -t IDENTITY <~/alastria/data/IDENTITY
GLOBAL_ARGS="--networkid $NETID --identity $IDENTITY --permissioned --rpc --rpcaddr 0.0.0.0 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,istanbul --rpcport 22000 --port 21000 --istanbul.requesttimeout 30000  --ethstats $IDENTITY:bb98a0b6442386d0cdf8a31b267892c1@52.56.86.239:3000 --verbosity 3 --vmdebug --emitcheckpoints --targetgaslimit 18446744073709551615 "

_TIME=$(date +%Y%m%d%H%M%S)

mapfile -t NODE_TYPE <~/alastria/data/NODE_TYPE

if [[ "$NODE_TYPE" == "general" ]]; then
    echo "[*] Starting Constellation node"
    nohup constellation-node ~/alastria/data/constellation/constellation.conf 2>> ~/alastria/logs/constellation_"${_TIME}".log &
    check_constellation_isStarted
fi

if [[ ! -f "permissioned-nodes.json" ]]; then
    # Esto es necesario por un bug de Quorum https://github.com/jpmorganchase/quorum/issues/225
    ln -s ~/alastria/data/permissioned-nodes.json permissioned-nodes.json
fi

echo "[*] Starting quorum node"
if [[ "$NODE_TYPE" == "general" ]]; then
    nohup env PRIVATE_CONFIG=~/alastria/data/constellation/constellation.conf geth --datadir ~/alastria/data $GLOBAL_ARGS 2>> ~/alastria/logs/quorum_"${_TIME}".log &
else
    if [[ "$NODE_TYPE" == "validator" ]]; then
        if [[ "$CURRENT_HOST_IP" == "52.56.69.220" ]]; then
            nohup geth --datadir ~/alastria/data $GLOBAL_ARGS --mine --minerthreads 1 --syncmode "full" --unlock 0 --password ~/alastria/data/passwords.txt 2>> ~/alastria/logs/quorum_"${_TIME}".log &
        else
            nohup geth --datadir ~/alastria/data $GLOBAL_ARGS --mine --minerthreads 1 --syncmode "full" 2>> ~/alastria/logs/quorum_"${_TIME}".log &
        fi
    fi
fi

if ([ ! $# -ne 1 ] && [ "dockerfile" == "$1" ]); then 
    
    echo "Running your node ..."
    while true; do
        sleep 1000000
    done;
fi

echo "[*] Verify if you are in develop branch"

set +u
set +e
