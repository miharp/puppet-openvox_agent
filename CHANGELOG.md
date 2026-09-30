# Changelog

Notable changes to openvox_agent are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/miharp/puppet-openvox_agent/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/miharp/puppet-openvox_agent/releases/tag/v0.1.0
