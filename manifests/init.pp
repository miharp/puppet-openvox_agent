# @summary Installs and upgrades openvox-agent from a Puppet run
#
# Assign it to agents to move them to a collection or version on their next
# run: from Puppet 7 to OpenVox 8, from OpenVox 8 to 9, or to a newer release
# within a collection. The class installs the collection's release package in
# place of the release packages of other OpenVox and Puppet major versions,
# ensures openvox-agent, and restarts the agent service once the package has
# changed.
#
# Hosts running openvox-server or openvoxdb, or the Puppet packages they
# replace, are left alone with a warning: those packages require a matching
# openvox-agent, so the agent moves with the server. Upgrade them with
# [ovadm](https://forge.puppet.com/modules/miharp/ovadm)'s `ovadm::upgrade`.
#
# @example Keep agents on the latest release of their current collection
#   class { 'openvox_agent':
#     package_version => 'latest',
#   }
#
# @example Move agents, including Puppet 7 agents, to OpenVox 8
#   class { 'openvox_agent':
#     collection => 'openvox8',
#   }
#
# @param collection
#   The collection to install from, such as `openvox8` or `openvox9`. When
#   unset, an OpenVox agent stays on the collection of the version it runs, and
#   a Puppet agent is left alone: switching from Puppet takes an explicit
#   collection.
#
# @param package_version
#   `present` (install if missing, never upgrade), `latest`, or a version such
#   as `8.29.0` or `9.0.0`. A bare version is expanded to the package version
#   for the platform (`8.29.0-1.el9`, `8.29.0-1+ubuntu24.04`); one containing a
#   `-` is used as it is.
#
# @param manage_repo
#   Whether to install the collection's release package and remove other
#   majors' release packages. Turn it off when the repository comes from
#   somewhere else, such as a mirror configured by another module.
#
# @param apt_source
#   Base URL the Debian and Ubuntu release package is downloaded from.
#
# @param yum_source
#   Base URL the EL release package is downloaded from.
#
# @param manage_service
#   Whether to restart the agent service after openvox-agent changes, and to
#   manage `service_ensure` and `service_enable` when they are set.
#
# @param service_name
#   The agent service.
#
# @param service_ensure
#   Whether the agent service should be running. Unmanaged when unset, so
#   sites that run the agent from cron or a timer are not given a daemon.
#
# @param service_enable
#   Whether the agent service starts at boot. Unmanaged when unset.
#
class openvox_agent (
  Optional[Pattern[/\Aopenvox\d+\z/]]  $collection      = undef,
  String[1]                            $package_version = 'present',
  Boolean                              $manage_repo     = true,
  Pattern[/\Ahttps?:\/\/\S+[^\/]\z/]   $apt_source      = 'https://apt.voxpupuli.org',
  Pattern[/\Ahttps?:\/\/\S+[^\/]\z/]   $yum_source      = 'https://yum.voxpupuli.org',
  Boolean                              $manage_service  = true,
  String[1]                            $service_name    = 'puppet',
  Optional[Enum['running', 'stopped']] $service_ensure  = undef,
  Optional[Boolean]                    $service_enable  = undef,
) {
  $state = $facts['openvox_agent'].lest || { {} }
  $agent_package = $state['agent_package']
  $server_packages = $state['server_packages'].lest || { [] }
  $held_packages = $state['held_packages'].lest || { [] }

  $resolved_collection = $collection.lest || {
    $agent_package ? {
      'openvox-agent' => "openvox${facts['aio_agent_version'].split('\.')[0]}",
      default         => undef,
    }
  }

  # Release packages are published per distribution release: debian12,
  # ubuntu24.04, el-9.
  $platform = $facts['os']['name'] ? {
    'Ubuntu' => "ubuntu${facts['os']['release']['full']}",
    'Debian' => "debian${facts['os']['release']['major']}",
    default  => "el${facts['os']['release']['major']}",
  }

  if !$server_packages.empty {
    warning(@("MSG"/L))
      openvox_agent: ${trusted['certname']} runs ${server_packages.join(', ')}, which \
      require a matching openvox-agent; leaving the agent alone. Upgrade the host \
      with ovadm::upgrade.
      | MSG
  } elsif $resolved_collection =~ Undef {
    warning(@("MSG"/L))
      openvox_agent: ${trusted['certname']} runs ${agent_package.lest || { 'no agent package' }}; \
      set collection (such as openvox8) to switch it to OpenVox.
      | MSG
  } else {
    unless $held_packages.empty {
      warning(@("MSG"/L))
        openvox_agent: ${held_packages.join(', ')} held on ${trusted['certname']} \
        (apt-mark hold or versionlock); the package manager will refuse to change it.
        | MSG
    }

    if $manage_repo {
      contain openvox_agent::repo
      Class['openvox_agent::repo'] -> Class['openvox_agent::install']
    }

    contain openvox_agent::install

    if $manage_service {
      contain openvox_agent::service
      Class['openvox_agent::install'] -> Class['openvox_agent::service']
    }
  }
}
