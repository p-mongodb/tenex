#!/bin/sh

set -e

#if test -z "$MONGODB_URI"; then
#  mkdir -p /data
#  mongod --dbpath /data --fork --logpath /data/mongod.log
#  export MONGODB_URI='mongodb://localhost/tenex?serverSelectionTimeoutMS=5000'
#fi

if test -n "$DOTENV"; then
  echo "$DOTENV" >.env
fi

erb mongodb_uri="$MONGODB_URI" config/mongoid.yml.docker >config/mongoid.yml

exec "$@"
