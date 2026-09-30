# Changelog

Notable changes to openvox_agent are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The `openvox_agent` class: installs the collection's release package in
  place of other OpenVox and Puppet major versions' release packages, ensures
  `openvox-agent` at a version, and queues a restart of the agent service when
  the package changes. Moves agents from Puppet 7 to OpenVox 8, from OpenVox 8
  to 9, and between releases within a collection. Server hosts and agents
  without an explicit collection to switch to are left alone with a warning.
- The `openvox_agent` fact: the agent package, installed release packages,
  server packages, and held agent packages.
- Debian 12 and 13, Ubuntu 22.04 and 24.04, and EL 8, 9 and 10.

[Unreleased]: https://github.com/miharp/puppet-openvox_agent/commits/main
