# @summary Restarts the agent service after an upgrade, and manages its state when asked
#
# @api private
#
class openvox_agent::service {
  $service_name = $openvox_agent::service_name

  if $openvox_agent::service_ensure or $openvox_agent::service_enable =~ Boolean {
    service { $service_name:
      ensure => $openvox_agent::service_ensure,
      enable => $openvox_agent::service_enable,
    }
  }

  # A daemon that has just had its package replaced keeps running the old code.
  # Restarting it from inside its own run with a plain `systemctl restart`
  # would wait for the daemon to stop, which waits for the run to finish.
  # --no-block queues the restart and returns; the daemon finishes the run
  # first. try-restart leaves an agent that is not running as a daemon alone.
  exec { 'openvox_agent restart after package change':
    command     => "systemctl --no-block try-restart ${service_name}.service",
    path        => ['/usr/bin', '/bin'],
    refreshonly => true,
    subscribe   => Package['openvox-agent'],
  }
}
