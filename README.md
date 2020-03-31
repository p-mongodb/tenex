# Tenex

Tenex is a mashup application built on top of
[Evergreen](https://github.com/evergreen-ci/evergreen/wiki),
[Travis](https://travis-ci.org/), Github and Jira APIs.
Its goal is to increase developer productivity by presenting
commonly needed data in an effective fashion, integrating the various
services used during development and providing shortcuts for commonly used
operations.

## Features

See README.features.md for a detailed list.

## Installation

Tenex uses MongoDB for persistence, Redis for background job storage
and is implemented in Ruby, therefore you'll need reasonably recent versions
of these dependencies installed. Then:

    git clone https://github.com/p-mongo/tenex
    cd tenex
    bundle install
    cp .env.sample .env

## Configuration

Edit `.env` file in project directory, and fill out:

- Your Evergreen credentials - get them [here](https://evergreen.mongodb.com/settings).
- Your Github credentials - create a personal access token [here](https://github.com/settings/tokens).
- Your Travis credentials - get it at https://travis-ci.org/profile/your-username/settings
(go to Profile -> Settings).

Note that the Github access token needs to have various scopes on it
to access various bits of functionality, but Github api documentation
does not specify which endpoints need which scopes. Checking the
"repo" check box is sufficient to enable all tenex functionality.

Edit `config/mongoid.yml` and change the host, port and database used for
MongoDB (note the MongoDB port specified by tenex is 27027, default MongoDB
port is 27017).

Redis address is currently not configurable (the default 127.0.0.1:6379 is used).

## Running

### In Development

    ./script/server

This launches a self-reloading web server on port 9393.

In production, use your favorite web server to run `.config.ru` (note the
leading dot).

### In Production

    puma .config.ru -b tcp://127.0.0.1:9393 -e production

Tenex presently does not perform authentication itself, therefore it should be
reverse-proxied to by a web server that has authentication configured.

## License

MIT
