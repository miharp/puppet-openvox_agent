# @summary Installs the collection's release package in place of other major versions'
#
# @api private
#
class openvox_agent::repo {
  $release = "${openvox_agent::resolved_collection}-release"
  $installed = $openvox_agent::state['release_packages'].lest || { [] }
  $stale = $installed.filter |$package| { $package != $release }

  case $facts['os']['family'] {
    'Debian': {
      # Every OpenVox release package ships
      # /etc/apt/preferences.d/openvox-release.pref, so dpkg refuses the new
      # one until the old one is gone. The download comes first, so a bad
      # URL leaves the old repository in place.
      $package_file = "/var/cache/openvox_agent/${release}-${openvox_agent::platform}.deb"

      file { '/var/cache/openvox_agent':
        ensure => directory,
      }

      file { $package_file:
        ensure => file,
        source => "${openvox_agent::apt_source}/${release}-${openvox_agent::platform}.deb",
      }

      package { $stale:
        ensure  => purged,
        require => File[$package_file],
        before  => Package[$release],
      }

      package { $release:
        ensure   => installed,
        provider => 'dpkg',
        source   => $package_file,
      }

      exec { 'openvox_agent apt-get update':
        command     => 'apt-get update',
        path        => ['/usr/bin', '/bin'],
        refreshonly => true,
        subscribe   => Package[$release],
      }
    }
    'RedHat': {
      # EL release packages install side by side; the old ones go once the new
      # one is in.
      package { $release:
        ensure   => installed,
        provider => 'rpm',
        source   => "${openvox_agent::yum_source}/${release}-el-${facts['os']['release']['major']}.noarch.rpm",
      }

      package { $stale:
        ensure   => absent,
        provider => 'rpm',
        require  => Package[$release],
      }
    }
    default: {
      fail("openvox_agent: ${facts['os']['family']} is not supported")
    }
  }
}
