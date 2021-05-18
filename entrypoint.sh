#!/bin/sh

set -e

#if test -z "$MONGODB_URI"; then
#  mkdir -p /data
#  mongod --dbpath /data --fork --logpath /data/mongod.log
#  export MONGODB_URI='mongodb://localhost/tenex?serverSelectionTimeoutMS=5000'
#fi

if test -n "$DOTENV"; then
  echo "$DOTENV" >config/env
fi

#erb mongodb_uri="$MONGODB_URI" config/mongoid.yml.docker >config/mongoid.yml

eval `ssh-agent`
for id in /etc/tenex/id_*; do
  if ! echo "$id" |egrep -q '\.pub$'; then
    ssh-add "$id"
  fi
done || true

exec "$@"
