# openvox_agent

[![CI](https://github.com/miharp/puppet-openvox_agent/actions/workflows/ci.yml/badge.svg)](https://github.com/miharp/puppet-openvox_agent/actions/workflows/ci.yml)
[![OpenVox compatible](https://img.shields.io/badge/OpenVox-8%20%7C%209-orange.svg)](https://voxpupuli.org/openvox/)
[![License](https://img.shields.io/github/license/miharp/puppet-openvox_agent)](https://github.com/miharp/puppet-openvox_agent/blob/main/LICENSE)

[![Puppet Forge](https://img.shields.io/puppetforge/v/miharp/openvox_agent)](https://forge.puppet.com/modules/miharp/openvox_agent)
[![Puppet Forge downloads](https://img.shields.io/puppetforge/dt/miharp/openvox_agent)](https://forge.puppet.com/modules/miharp/openvox_agent)

Installs and upgrades `openvox-agent` from a Puppet run: from Puppet 7 to
OpenVox 8, from OpenVox 8 to 9, or to a newer release within a collection.
It is the OpenVox counterpart to the `puppetlabs-puppet_agent` class, whose
`collection` parameter only knows Puppet's repositories.

Assign the class to your agents and set the collection; each agent switches on
its next run.

```puppet
class { 'openvox_agent':
  collection => 'openvox8',
}
```

## What a run does

1. **Switches the package repository.** Installs the collection's release
   package (`openvox8-release`, say) from
   [apt.voxpupuli.org](https://apt.voxpupuli.org) or
   [yum.voxpupuli.org](https://yum.voxpupuli.org), and removes the release
   packages of other OpenVox and Puppet major versions (`openvox7-release`,
   `puppet7-release`). On Debian and Ubuntu the old OpenVox release package
   has to go first, since each ships the same apt preferences file; on EL the
   old ones are removed after the new one is in.
2. **Installs openvox-agent** at `package_version`. It replaces `puppet-agent`
   directly: the package declares Conflicts and Replaces (deb) or Obsoletes
   (rpm) on it, and `puppet.conf`, the SSL directory and the certificates are
   kept. No OpenVox 7 step is needed between Puppet 7 and OpenVox 8.
3. **Puts the agent service back** the way it was when the run started.
   Replacing `puppet-agent` stops the `puppet` service in the middle of the
   run (on EL it also disables it), and an upgraded daemon keeps running the
   old code. So when the package has changed, a daemon that was running is
   restarted and one that was enabled is enabled again; one that was not
   running stays stopped. The restart is queued rather than waited for, so a
   daemon upgrading itself finishes the run first.

Read the upstream upgrade guide before moving a fleet to a new major version:
most of what changes is in the language and the agent's defaults, which this
module does not touch.

## Usage

Keep every agent on the latest release of its current collection:

```puppet
class { 'openvox_agent':
  package_version => 'latest',
}
```

Pin a version. A bare version is expanded for the platform (`8.29.0-1.el9`,
`8.29.0-1+ubuntu24.04`); a full package version is used as it is:

```puppet
class { 'openvox_agent':
  collection      => 'openvox9',
  package_version => '9.0.0',
}
```

Use a mirror of the Vox Pupuli repositories:

```puppet
class { 'openvox_agent':
  collection => 'openvox8',
  apt_source => 'https://mirror.example.com/apt.voxpupuli.org',
  yum_source => 'https://mirror.example.com/yum.voxpupuli.org',
}
```

If another module manages the repository, set `manage_repo => false` and the
class only manages the package and the restart.

See [REFERENCE.md](https://github.com/miharp/puppet-openvox_agent/blob/main/REFERENCE.md)
for every parameter.

## What it leaves alone

- **Agents without a collection.** With `collection` unset, an OpenVox agent
  stays on the collection it runs, and a Puppet agent is left as it is with a
  warning. Switching from Puppet always takes an explicit collection, so the
  class is safe to include everywhere.
- **Server hosts.** `openvox-server` and `openvoxdb` require a matching
  `openvox-agent`, so on hosts running them (or `puppetserver` and `puppetdb`)
  the class does nothing and logs a warning. Upgrade those with
  [ovadm](https://forge.puppet.com/modules/miharp/ovadm)'s `ovadm::upgrade`,
  server first, then agents: an OpenVox 8 agent cannot use a Puppet 7 server.
- **Holds.** An `apt-mark hold` or dnf/yum `versionlock` on the agent package
  is reported in a warning, not removed. The package manager refuses the
  change until you lift it.
- **The service state.** Unless you set `service_ensure` and
  `service_enable`, the service ends each run the way it started it, so sites
  running the agent from cron or a timer are not given a daemon.
- **Agent settings.** Use `puppetlabs-puppet_conf` or `theforeman-puppet` for
  `puppet.conf`.

## Facts

The module ships one structured fact, `openvox_agent`, with the package state
the class needs:

| Key | Value |
| --- | --- |
| `agent_package` | `openvox-agent` or `puppet-agent` |
| `release_packages` | installed `openvox<N>-release` and `puppet<N>-release` packages |
| `server_packages` | installed `openvox-server`, `openvoxdb`, `puppetserver`, `puppetdb` |
| `held_packages` | agent packages held by apt-mark or versionlock |
| `service` | whether `puppet.service` was `running` and `enabled` when the run started |

## Limitations

- Linux only: Debian 12 and 13, Ubuntu 22.04 and 24.04, and EL 8, 9 and 10
  (RHEL, AlmaLinux, Rocky, Oracle Linux). Windows, macOS and SLES are not
  supported yet.
- The catalog is compiled on the server, which is upgraded first, so the
  module requires OpenVox 8 or 9 there. The agents it upgrades can be
  Puppet 7.

## Development

Unit tests and static checks run in the Vox Pupuli voxbox container:

```console
docker run --rm -v "$PWD:/repo" ghcr.io/voxpupuli/voxbox:8 validate lint check rubocop spec
```

Acceptance tests run with Beaker in a systemd container. With
`BEAKER_PUPPET_COLLECTION=puppet7` the host starts on Puppet 7:

```console
BEAKER_SETFILE=almalinux9-64 BEAKER_PUPPET_COLLECTION=openvox8 bundle exec rake beaker
BEAKER_SETFILE=ubuntu2204-64 BEAKER_PUPPET_COLLECTION=puppet7 bundle exec rake beaker
```
