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

  # Installing openvox-agent replaces puppet-agent: the package declares
  # Conflicts and Replaces (deb) or Obsoletes (rpm) on it.
  package { 'openvox-agent':
    ensure          => $package_ensure,
    install_options => $install_options,
  }
}
