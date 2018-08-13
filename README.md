# Tenex

Tenex is a mashup application built on top of
[Evergreen](https://github.com/evergreen-ci/evergreen/wiki),
[Travis](https://travis-ci.org/) and Github APIs.
Its goal is to increase developer productivity by presenting
commonly needed data in an effective fashion as well as providing
shortcuts to commonly used operations.

## Features

### Pull Request CI Status

Tenex merges Evergreen and Travis CI statuses on a single page.
Travis statuses are expanded to job level.
Evergreen statuses are arranged in a matrix for supported projects
(Ruby driver).

PR status page adds a link to restart all failed Evergreen tasks.

### Evengreen Patch Status

Adds a link to jump to the patch status page for the newest version
of the branch being shown.

### Evergreen Spawn Hosts

Adds a list of recently spawned distros for quickly spawning more of
the same distros.

Adds a link to terminate all running spawned hosts.

Adds an SSH command copy-pastable to the terminal to connect to each
spawned host.

## Configuration

Get credentials from [here](https://evergreen.mongodb.com/settings).

## License

MIT
