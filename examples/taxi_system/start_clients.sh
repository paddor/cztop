#!/bin/sh -x
export BROKER_ADDRESS=tcp://127.0.0.1:4455
export BROKER_CERT=public_keys/broker
CLIENT_CERT=secret_keys/drivers/driver1_secret ./client.rb &
CLIENT_CERT=secret_keys/drivers/driver2_secret ./client.rb &
CLIENT_CERT=secret_keys/drivers/driver3_secret ./client.rb &
jobs
jobs -p
jobs -l
trap 'kill $(jobs -p)' EXIT
wait
