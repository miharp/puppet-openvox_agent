# Changelog

Notable changes to openvox_agent are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `manage_server_hosts`: manage the agent on a host running openvox-server
  or openvoxdb, for a module that moves the server package first and orders
  it between the repository and the agent, the way
  [openvox_server](https://forge.puppet.com/modules/miharp/openvox_server)
  does. Off by default, so server hosts are left alone as before.
- `$openvox_agent::left_alone`: the reason the class leaves a host alone,
  or undef, for a module declaring the class to act on.
- The `openvox_agent::repo` class is public, so that another module can
  order a package between the repository and the agent, and
  `openvox_agent::platform` and `openvox_agent::package_version` are public
  functions: the distribution release string and the bare-version expansion
  openvox_server versions the server package with.

## [0.1.1] - 2026-09-30

### Fixed

- A `package_version` pinned to a release published since the package index
  was last refreshed failed with "version not found" (apt) or "no match"
  (dnf): the index was only refreshed when the release package changed. It is
  now refreshed whenever the installed version is not the pinned one, which
  also covers `manage_repo => false`.

## [0.1.0] - 2026-09-30

### Added

- The `openvox_agent` class: installs the collection's release package in
  place of other OpenVox and Puppet major versions' release packages, ensures
  `openvox-agent` at a version, and puts the agent service back the way it
  was when the run started: replacing `puppet-agent` stops the service (and
  on EL disables it) in the middle of the run. Moves agents from Puppet 7 to
  OpenVox 8, from OpenVox 8 to 9, and between releases within a collection.
  Left alone with a warning: server hosts, agents without an explicit
  collection to switch to, and agents that would move to OpenVox 9 while
  reaching their server only through the implicit `server=puppet` it removed.
- The `openvox_agent` fact: the agent package, installed release packages,
  server packages, held agent packages, the agent service's state, and
  whether the agent's server is configured rather than defaulted.
- Debian 12 and 13, Ubuntu 22.04 and 24.04, and EL 8, 9 and 10.

[Unreleased]: https://github.com/miharp/puppet-openvox_agent/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/miharp/puppet-openvox_agent/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/miharp/puppet-openvox_agent/releases/tag/v0.1.0
