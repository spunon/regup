#!/bin/sh

if [ "$CONSUL_PROTOCOL" = "" ]; then
    export CONSUL_PROTOCOL="http"
    echo "Using default CONSUL_PROTOCOL value: $CONSUL_PROTOCOL"
fi

# Trapping and cleanup to deregister service upon pod exit
trap cleanup 1 2 3 6 15 19 20 
cleanup()
{
    echo "Caught signal, removing registration for $SERVICE_ID."
    curl -s \
        --request PUT \
        $CONSUL_PROTOCOL://$NODE_IP:8500/v1/agent/service/deregister/$SERVICE_ID;
    echo "Service $SERVICE_NAME has been deregistered, exiting."
    exit 1
}

# Set SERVICE_IP based on the variable passed into address_type
if [ "$ADDRESS_TYPE" = "NODE" ]; then
    export SERVICE_IP=$NODE_IP
else
    export SERVICE_IP=$POD_IP
fi

export SERVICE_PORT
export SERVICE_ID=$SERVICE_NAME-$SERVICE_IP

# Append UNIQUE_ID to the end of the service name if it exists
# For registering multiple of the same service on one machine (e.g. minikube)
if [ ! -z $UNIQUE_ID ]; then
    export SERVICE_ID=$SERVICE_ID-$UNIQUE_ID
fi

# Check to see if HEALTH_TYPE was set, to see if we need to render
# the healtcheck template that will be placed inside the payload
if [ "$HEALTH_TYPE" != "" ]; then
    echo "Health Type: $HEALTH_TYPE"

    if [ "$(echo $HEALTH_TYPE | tr '[:upper:]' '[:lower:]')" = "script" ]; then
        if [ "$HEALTH_SCRIPT" = "" ]; then
            echo "FATAL: ENV HEALTH_TYPE is set to $HEALTH_TYPE, but ENV HEALTH_SCRIPT is not set, exiting."
            exit 1
        fi
        if [ "$HEALTH_ENDPOINT" != "" ]; then
            echo "WARN: ENV HEALTH_ENDPOINT is set with HEALTH_TYPE of $HEALTH_TYPE - Disabling HEALTH_ENDPOINT."
            echo "WARN: Only use HEALTH_ENDPOINT with HEALTH_TYPE of HTTP/TCP"
            export HEALTH_ENDPOINT=""
        fi  

        # Render health check script
        echo $HEALTH_SCRIPT>script.json
        HEALTH_SCRIPT=$(echo $(cat script.json) | envsubst)
        export HEALTH_SCRIPT="\"/bin/sh -c \\\"$HEALTH_SCRIPT\\\"\""
    else 
        if [ "$HEALTH_ENDPOINT" = "" ]; then
            echo "FATAL: ENV HEALTH_ENDPOINT has not been set, exiting."
            exit 1
        fi
        if [ "$HEALTH_SCRIPT" != "" ]; then
            echo "WARN: ENV HEALTH_SCRIPT is set with HEALTH_TYPE of $HEALTH_TYPE - Disabling HEALTH_SCRIPT."
            echo "WARN: Only use HEALTH_SCRIPT with HEALTH_TYPE of Script"
            export HEALTH_SCRIPT=""
        fi

        # Render health check endpoint
        echo $HEALTH_ENDPOINT>endpoint.json
        HEALTH_ENDPOINT=$(echo $(cat endpoint.json) | envsubst)
        export HEALTH_ENDPOINT="\"$HEALTH_ENDPOINT\""
    fi

    # Set defaults and alert for non-required health check fields
    if [ "$HEALTH_DEREGISTER_AFTER" = "" ]; then
        export HEALTH_DEREGISTER_AFTER="1m"
        echo "Using default HEALTH_DEREGISTER_AFTER value: $HEALTH_DEREGISTER_AFTER"
    fi
    if [ "$HEALTH_INTERVAL" = "" ]; then
        export HEALTH_INTERVAL="10s"
        echo "Using default HEALTH_INTERVAL value: $HEALTH_INTERVAL"
    fi
    if [ "$HEALTH_TIMEOUT" = "" ]; then
        export HEALTH_TIMEOUT="1s"
        echo "Using default HEALTH_TIMEOUT value: $HEALTH_TIMEOUT"
    fi
    if [ "$HEALTH_TLS_SKIP_VERIFY" = "" ]; then
        export HEALTH_TLS_SKIP_VERIFY="true"
        echo "Using default HEALTH_TLS_SKIP_VERIFY value: $HEALTH_TLS_SKIP_VERIFY"
    fi
    export CHECK_SCRIPT=$(echo $(cat check.json) | envsubst)
fi

# Render and write final json payload
PAYLOAD=$(echo $(cat payload.json) | envsubst)
echo $PAYLOAD>/reg.json

echo "Registering with Consul Agent: $CONSUL_PROTOCOL://$NODE_IP:8500"
echo "Registering $SERVICE_ID in Consul as Service: $SERVICE_NAME, Address: $SERVICE_IP, Port: $SERVICE_PORT"
echo "Registration JSON:"
cat /reg.json

# Loop until the container catches a signal to shutdown
while true; do

    # Register the service continually in consul with the json object you've constructed
    # Registration happens continually in case your main container dies and is restarted without 
    # the entire pod being restarted. If the pod goes away HEALTH_DEREGISTER_INTERVAL will clean up
    # the orphaned service eventually. It will be unhealthy and won't serve traffic in the mean time
    curl -s \
        --request PUT \
        --data @reg.json \
        $CONSUL_PROTOCOL://${NODE_IP}:8500/v1/agent/service/register

    # Sleep for half the default automatic deregistration time
    sleep 30
done


