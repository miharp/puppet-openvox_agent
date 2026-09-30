# Move every agent, including Puppet 7 agents, to the latest OpenVox 8
# release on its next run. Server hosts are skipped with a warning.
class { 'openvox_agent':
  collection      => 'openvox8',
  package_version => 'latest',
}
