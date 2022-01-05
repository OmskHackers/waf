#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "usage: modsec_up.sh [port] [address] [absolute path to config folder] [address to WS(optionally)]"
    exit
fi

docker run -p $1:80 -dti \
-e BACKEND_WS=$4 -e EXECUTING_PARANOIA=10 -e ANOMALY_INBOUND=10 -e MODSEC_REQ_BODY_ACCESS=on -e ANOMALY_OUTBOUND=5 -e PROXY=1 -e BACKEND=$2 -e MODSEC_RULE_ENGINE=on \
-v $3:/opt/owasp-crs/rules:ro \
--rm owasp/modsecurity-crs:nginx-alpine
