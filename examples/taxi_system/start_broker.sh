#!/bin/sh -x
BROKER_ADDRESS=tcp://127.0.0.1:4455 BROKER_CERT=secret_keys/broker CLIENT_CERTS=public_keys/drivers ./broker.rb
