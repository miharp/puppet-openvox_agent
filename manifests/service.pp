# @summary Puts the agent service back after openvox-agent changes, and manages its state when asked
#
# @api private
#
class openvox_agent::service {
  $service_name = $openvox_agent::service_name
  $unit = "${service_name}.service"
  $at_run_start = $openvox_agent::state['service'].lest || { {} }

  $manage_state = $openvox_agent::service_ensure =~ NotUndef or $openvox_agent::service_enable =~ Boolean
  if $manage_state {
    service { $service_name:
      ensure => $openvox_agent::service_ensure,
      enable => $openvox_agent::service_enable,
    }
  }

  # Replacing puppet-agent runs its removal script, which stops the service,
  # and on EL disables it, in the middle of this run. Upgrading openvox-agent
  # leaves a running daemon on the old code. So once the package has changed,
  # put the service back the way it was when the run started (from the
  # openvox_agent fact), or as service_ensure and service_enable say.
  $running = $openvox_agent::service_ensure ? {
    'running' => true,
    'stopped' => false,
    default   => $at_run_start['running'] == true,
  }
  $enabled = $openvox_agent::service_enable ? {
    Boolean => $openvox_agent::service_enable,
    default => $at_run_start['enabled'] == true,
  }

  # --no-block queues the restart and returns: when the daemon is still
  # running, a blocking restart would wait for it, and it waits for this run.
  $commands = [
    if $enabled { "systemctl enable ${unit}" },
    if $running { "systemctl --no-block restart ${unit}" },
  ].filter |$command| { $command =~ NotUndef }

  unless $commands.empty {
    exec { 'openvox_agent restore agent service after package change':
      command     => $commands.join(' && '),
      provider    => 'shell',
      path        => ['/usr/bin', '/bin'],
      refreshonly => true,
      subscribe   => Package['openvox-agent'],
    }

    if $manage_state {
      Service[$service_name] -> Exec['openvox_agent restore agent service after package change']
    }
  }
}
