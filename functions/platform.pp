# @summary The distribution release the OpenVox packages are built for
#
# Release packages and package versions are per distribution release:
# `debian12`, `ubuntu24.04`, `el9`.
#
# @return [String[1]] The platform string.
function openvox_agent::platform() >> String[1] {
  $facts['os']['name'] ? {
    'Ubuntu' => "ubuntu${facts['os']['release']['full']}",
    'Debian' => "debian${facts['os']['release']['major']}",
    default  => "el${facts['os']['release']['major']}",
  }
}
