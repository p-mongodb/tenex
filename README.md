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
- Shows Github PR review approved/requested status.

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
- One click to restart all failed tasks for a PR.
- One click jump to parsed test suite results (RSpec/JUnit XML) for
each configuration tested.
- One click review request.
- Button to rebase branch on master.
- Button to squash commits in a branch and replace commit messsages with
the respective ticket title.
- One click PR retitle to match subject & message of the head commit.
- Smart failure counting: top level Evergreen build is not included in
the number of the failing builds, and if Travis is ignored then Travis
failures also are not included in the number of failures.
- Ability to bulk bump task priorities for unfinished tasks for all evergreen
builds started by the PR.

![PR](https://raw.githubusercontent.com/wiki/p-mongo/tenex/screenshots/pr.png) 

### Evergreen Patch Status

Adds a link to jump to the patch status page for the newest version
of the branch being shown.

Adds ability to bulk bump task priorities for unfinished tasks in
a version, individually or in bulk for all unfinished tasks.

![PR](https://raw.githubusercontent.com/wiki/p-mongo/tenex/screenshots/version.png) 

![PR](https://raw.githubusercontent.com/wiki/p-mongo/tenex/screenshots/version-2.png) 

### Evergreen Log

Reinstates normal horizontal scrollbar in task logs.

Adds a quick jump to first RSpec failure.

### Travis Log

Full build log with color.

### Failure Reporting From JUnit XML Results

If the test suite outputs its results in JUnit XML format, Tenex will
provide a list of failed tests for each Evergreen task.

### Toolchain Tarball Retrieval

Allows quickly getting URLs of built toolchain tarballs for the most
recent master commit of the toolchain.

![Toolchain URLs](https://raw.githubusercontent.com/wiki/p-mongo/tenex/screenshots/toolchain-urls.png) 

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

Note that the Github access token needs to have various scopes on it
to access various bits of functionality, but Github api documentation
does not specify which endpoints need which scopes. Checking the
"repo" check box is sufficient to enable all tenex functionality.

Edit `config/mongoid.yml` and change the host, port and database used for
MongoDB (note the MongoDB port specified by tenex is 27027, default MongoDB
port is 27017).

## Running

### In Development

    ./script/server

This launches a self-reloading web server on port 9393.

In production, use your favorite web server to run `.config.ru` (note the
leading dot).

### In Production

    puma .config.ru -b tcp://127.0.0.1:9393 -e production

Tenex presently does not perform authentication itself, therefore it should be reverse-proxied to by a web server that has authentication configured.

## License

MIT
