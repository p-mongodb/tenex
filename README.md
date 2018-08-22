# Tenex

Tenex is a mashup application built on top of
[Evergreen](https://github.com/evergreen-ci/evergreen/wiki),
[Travis](https://travis-ci.org/) and Github APIs.
Its goal is to increase developer productivity by presenting
commonly needed data in an effective fashion as well as providing
shortcuts for commonly used operations.

## Features

### General

- Reasonably quick operation in interactive use.
- No jumping content due to multiple renders.
- If a project uses Evergreen and Travis, results from both are shown
whenever results from one are shown and results from both systems are
presented in a similar fashion.

### Pull Request List

- Shows Evergreen & Travis build stats for each PR.

![PR list](https://raw.githubusercontent.com/wiki/p-mongo/tenex/screenshots/pr-list.png) 

### Pull Request CI Status

Tenex merges Evergreen and Travis CI statuses on a single page.
Travis statuses are expanded to job level.
Evergreen statuses are arranged in a matrix for supported projects
(Ruby driver).

PR status page adds:
- A link to restart all failed Evergreen tasks.
- One click jump to full Evergreen task logs.
- One click jump to full Travis logs.
- One click to restart a task.

![PR](https://raw.githubusercontent.com/wiki/p-mongo/tenex/screenshots/pr.png) 

### Evergreen Patch Status

Adds a link to jump to the patch status page for the newest version
of the branch being shown.

![PR](https://raw.githubusercontent.com/wiki/p-mongo/tenex/screenshots/version.png) 

### Evergreen Log

Reinstates normal horizontal scrollbar in task logs.

Adds a quick jump to first RSpec failure.

### Travis Log

Full build log with color.

### Evergreen Spawn Hosts

Adds a list of recently spawned distros for quickly spawning more of
the same distros.

Adds a link to terminate all running spawned hosts.

Adds an SSH command copy-pastable to the terminal to connect to each
spawned host.

![Spawn page](https://raw.githubusercontent.com/wiki/p-mongo/tenex/screenshots/spawn.png) 

## Installation

Tenex uses MongoDB for persistence and is implemented in Ruby, therefore
you'll need reasonably recent versions of both of these installed. Then:

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

Edit `config/mongoid.yml` and change the host, port and database used for
MongoDB (note the MongoDB port specified by tenex is 27027, default MongoDB
port is 27017).

## Running

In development:

    ./script/server

This launches a self-reloading web server on port 9393.

In production, use your favorite web server to run `.config.ru` (note the
leading dot).

## License

MIT
