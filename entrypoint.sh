#!/bin/sh

set -ex

if test -z "$MONGODB_URI"; then
  mkdir -p /data
  mongod --dbpath /data --fork --logpath /data/mongod.log
  export MONGODB_URI='mongodb://localhost/tenex?serverSelectionTimeout=5'
fi

erb mongodb_uri="$MONGODB_URI" config/mongoid.yml.docker >config/mongoid.yml

exec "$@"
