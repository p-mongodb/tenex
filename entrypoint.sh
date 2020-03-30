#!/bin/sh

set -ex

erb mongodb_uri="$MONGODB_URI" config/mongoid.yml.docker >config/mongoid.yml

exec "$@"
