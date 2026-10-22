# @summary Ensures openvox-agent
#
# @api private
#
class openvox_agent::install {
  $version = $openvox_agent::package_version

  $package_ensure = openvox_agent::package_version($version, $openvox_agent::platform, $facts['os']['family'])

  # OpenVox builds separate agent packages for Enterprise Linux hosts in FIPS
  # mode (redhatfips9 instead of el9), and a host moves between them as an
  # ordinary package change: an upgrade to redhatfips, a downgrade to el.
  # The transaction to redhatfips leaves the agent without its OpenSSL
  # configuration, though: the redhatfips package writes
  # /opt/puppetlabs/puppet/ssl/openssl.cnf from its post-install script and
  # does not own it, the el package ships that path as a file, and rpm
  # removes the old package's files after the new one's scripts have run.
  # Without the file the FIPS provider is silently not loaded, so put it
  # back the way the post-install script does. A no-op whenever it exists.
  if $openvox_agent::platform =~ /\Aredhatfips/ {
    $ssl_dir = '/opt/puppetlabs/puppet/ssl'
    exec { 'openvox_agent restore the FIPS OpenSSL configuration':
      command  => "cp --preserve ${ssl_dir}/openssl-fips.cnf ${ssl_dir}/openssl.cnf && chmod 0644 ${ssl_dir}/openssl.cnf",
      onlyif   => "test -f ${ssl_dir}/openssl-fips.cnf -a ! -f ${ssl_dir}/openssl.cnf",
      path     => ['/usr/bin', '/bin'],
      provider => 'shell',
      require  => Package['openvox-agent'],
    }
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
