# @summary Expands a bare version to the platform's package version
#
# `present`, `installed`, `latest` and versions containing a `-` are returned
# as they are. A bare version such as `8.29.0` becomes `8.29.0-1+debian12` on
# Debian and Ubuntu and `8.29.0-1.el9` on EL, the way the OpenVox packages
# are versioned. Shared with openvox_server, which versions openvox-server
# the same way.
#
# @param version
#   The requested version.
# @param platform
#   The distribution release the packages are built for, from
#   `openvox_agent::platform`.
# @param os_family
#   The `os.family` fact.
# @return [String[1]] The package version to ensure.
function openvox_agent::package_version(
  String[1] $version,
  String[1] $platform,
  String[1] $os_family,
) >> String[1] {
  $version ? {
    /\A(present|installed|latest)\z/ => $version,
    /-/                              => $version,
    default                          => $os_family ? {
      'Debian' => "${version}-1+${platform}",
      default  => "${version}-1.${platform}",
    },
  }
}
