#!/bin/sh

# Trapping and cleanup to deregister service upon pod exit
trap cleanup 1 2 3 6 15 19 20 
cleanup()
{
    echo "Caught signal, removing registration for ${SERVICE_ID}."
    curl -s \
        --request PUT \
        http://${NODE_IP}:8500/v1/agent/service/deregister/${SERVICE_ID};
    echo "Done cleaning up, exiting."
    exit 1
}

# Set service_ip based on the variable passed into address_type
if [ "$ADDRESS_TYPE" = "NODE" ]; then
    export SERVICE_IP=${NODE_IP}
else
    export SERVICE_IP=${POD_IP}
fi

# Set Service ID as Name-IP
SERVICE_ID=${SERVICE_NAME}-$RANDOM

# Check to see if health protocol was set, to see if we need to
# render the healtcheck template that will be placed inside the payload
if [ ! -z "${HEALTH_TYPE}" ]; then

    echo "Health Type: ${HEALTH_TYPE}"

    if [ "$(echo ${HEALTH_TYPE} | tr '[:upper:]' '[:lower:]')" = "script" ]; then
        if [ -z "${HEATH_SCRIPT}" ]; then
            echo "ENV HEALTH_TYPE is set to ${HEALTH_TYPE}, but ENV HEALTH_SCRIPT is not set, exiting."
            exit 1
            if [ ! -z "${HEALTH_ENDPOINT}" ]; then
                echo "WARN: "
            fi
        fi
        if [ $(echo ${HEALTH_SCRIPT} | grep " "}) ]; then
            export HEALTH_TYPE="args"
            export HEALTH_SCRIPT=$(echo -e "[\"$(echo ${HEALTH_SCRIPT} | sed 's/ /\", \"/g')\"]")
        fi
    else 
        if [ -z "${HEALTH_ENDPOINT}" ]; then
            echo "ENV HEALTH_ENDPOINT has not been set, exiting."
            exit 1
        fi
    fi

    # Set defaults for non-required health check fields
    if [ -z "${HEALTH_DEREGISTER_AFTER}" ]; then
        export HEALTH_DEREGISTER_AFTER="1m"
    fi
    if [ -z "${HEALTH_INTERVAL}" ]; then
        export HEALTH_INTERVAL="10s"
    fi
    if [ -z "${HEALTH_TIMEOUT}" ]; then
        export HEALTH_TIMEOUT="1s"
    fi
    if [ -z "${HEALTH_TLS_SKIP_VERIFY}" ]; then
        export HEALTH_TLS_SKIP_VERIFY="true"
    fi
    
    export HEALTH_ENDPOINT=$(eval echo -e "${HEALTH_ENDPOINT}")
    export HEALTHTMPL=$(cat /check.json)
    export CHECK_SCRIPT=$(eval echo -e \"$HEALTHTMPL\")
fi

# Render the payload template
JSONTMPL=$(cat /payload.json)
PAYLOAD=$(eval echo -e \"$JSONTMPL\")
echo $PAYLOAD>reg.json
echo "Registering ${SERVICE_ID} in consul as service: ${SERVICE_NAME} address: ${SERVICE_IP} port: ${SERVICE_PORT}"
echo "Registration JSON:"
cat /reg.json | jq

# Loop until the container catches a signal to shutdown
while true; do
    # Register the service continually in consul with the json blob you've constructed
    # Registration happens continually in case your main pod dies and is restarted without the 
    # entire pod being restarted. If the pod goes away HEALTH_DEREGISTER_INTERVAL will clean up
    # the orphaned service eventually. It will be unhealthy/not serve traffic in the mean time
    curl -s \
        --request PUT \
        --data @reg.json \
        http://${NODE_IP}:8500/v1/agent/service/register
        
    # Sleep for half the automatic deregistration time
    sleep 30
done


