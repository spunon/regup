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
    if [ -z "${HEALTH_ENDPOINT}" ]; then
        echo "Environment Variable HEALTH_ENDPOINT has not been set, exiting."
        exit 1
    fi
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
cat /reg.json


# Register the service in consul with the json blob you've constructed
curl -s \
    --request PUT \
    --data @reg.json \
    http://${NODE_IP}:8500/v1/agent/service/register

# Loop until the container catches a signal to shutdown
while true; do
    sleep 5
done


