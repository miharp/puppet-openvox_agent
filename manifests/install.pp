# @summary Ensures openvox-agent
#
# @api private
#
class openvox_agent::install {
  $version = $openvox_agent::package_version

  $package_ensure = $version ? {
    /\A(present|installed|latest)\z/ => $version,
    /-/                              => $version,
    default                          => $facts['os']['family'] ? {
      'Debian' => "${version}-1+${openvox_agent::platform}",
      default  => "${version}-1.${openvox_agent::platform}",
    },
  }

  # apt refuses a lower version without being told, dnf does not.
  if $facts['os']['family'] == 'Debian' and $version !~ /\A(present|installed|latest)\z/ {
    $install_options = ['--allow-downgrades']
  } else {
    $install_options = []
  }

  # The package index is refreshed when the release package changes, not when
  # the pin moves: a version published since the last refresh is not in it,
  # apt reports it not found and dnf does not look past its cached metadata.
  # Refresh when the installed version is not the pinned one, and only then,
  # so a converged node does not hit the mirror on every run. present and
  # latest are left to the OS's own index refresh (apt-daily, dnf-makecache).
  if $package_ensure !~ /\A(present|installed|latest)\z/ {
    if $facts['os']['family'] == 'Debian' {
      $refresh = 'apt-get update'
      $installed = "dpkg-query -W -f='\${Version}' openvox-agent 2>/dev/null"
    } else {
      $refresh = 'dnf clean expire-cache'
      $installed = "rpm -q --queryformat '%{VERSION}-%{RELEASE}' openvox-agent 2>/dev/null"
    }

    exec { 'openvox_agent refresh the package index for the pinned version':
      command  => $refresh,
      unless   => "${installed} | grep -qxF '${package_ensure}'",
      path     => ['/usr/bin', '/bin'],
      provider => 'shell',
      before   => Package['openvox-agent'],
    }
  }

  # Installing openvox-agent replaces puppet-agent: the package declares
  # Conflicts and Replaces (deb) or Obsoletes (rpm) on it.
  package { 'openvox-agent':
    ensure          => $package_ensure,
    install_options => $install_options,
  }
}
