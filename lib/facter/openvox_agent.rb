# frozen_string_literal: true

# Package state the openvox_agent class needs and Puppet core does not report.
# It runs on the agent being upgraded, which can still be Puppet 7, so it stays
# compatible with Ruby 2.7.
#
# - agent_package: openvox-agent or puppet-agent, whichever is installed
# - release_packages: installed (openvox|puppet)<N>-release packages, the ones
#   to replace when switching collections. On Debian this includes packages
#   removed but not purged, whose repository files are still in place.
# - server_packages: installed server-side packages (openvox-server, openvoxdb
#   and their Puppet predecessors), which pin openvox-agent to their own version
# - held_packages: agent packages held by apt-mark or dnf/yum versionlock,
#   which block an upgrade
# - fips_build: whether the installed openvox-agent is the redhatfips build
#   that OpenVox publishes for Enterprise Linux hosts in FIPS mode; nil on
#   Debian-family hosts and when openvox-agent is not installed
# - release_platforms: on EL, the platform each installed release package was
#   built for (openvox8-release => el9 or redhatfips9), from its release tag.
#   The el and redhatfips release packages share a name, so this is the only
#   way to tell which repository a host has. Empty on Debian-family hosts.
# - service: whether puppet.service was running and enabled when the run
#   started. Replacing puppet-agent stops the service (and on EL disables it)
#   in the middle of the run, so the class needs the state from before.
# - server_configured: whether the agent finds its server through its own
#   configuration (server or server_list set, or SRV records) rather than the
#   implicit server=puppet that OpenVox 9 removed. nil when Puppet's settings
#   are not loaded, such as under a standalone facter.
Facter.add(:openvox_agent) do
  confine kernel: 'Linux'

  setcode do
    release_pattern = %r{\A(openvox|puppet)\d+-release\z}
    server_names = %w[openvox-server openvoxdb puppetserver puppetdb]
    agent_names = %w[openvox-agent puppet-agent]

    if Facter::Core::Execution.which('dpkg-query')
      # ${db:Status-Abbrev} is two letters: the wanted state (i install,
      # h hold, r remove, ...) and the current one (i installed,
      # c config-files, n not installed, ...).
      states = Facter::Core::Execution.execute("dpkg-query -W -f='${Package} ${db:Status-Abbrev}\\n'", on_fail: '')
                                      .lines.map(&:split).select { |fields| fields.length == 2 }
      installed = states.select { |_name, status| status[1] == 'i' }.map(&:first)
      present = states.reject { |_name, status| status[1] == 'n' }.map(&:first)
      held = Facter::Core::Execution.execute('apt-mark showhold', on_fail: '').split
      fips_build = nil
      release_platforms = {}
    elsif Facter::Core::Execution.which('rpm')
      installed = Facter::Core::Execution.execute("rpm -qa --queryformat '%{NAME}\\n'", on_fail: '').split
      present = installed
      lock_files = ['/etc/dnf/plugins/versionlock.list', '/etc/yum/pluginconf.d/versionlock.list']
      locked = lock_files.select { |f| File.readable?(f) }.flat_map { |f| File.readlines(f) }
      # Entries look like "puppet-agent-0:7.34.0-1.el9.*" (or without the epoch).
      held = agent_names.select { |name| locked.any? { |line| line.start_with?("#{name}-") } }
      fips_build = nil
      if installed.include?('openvox-agent')
        release = Facter::Core::Execution.execute("rpm -q --queryformat '%{RELEASE}' openvox-agent", on_fail: '')
        fips_build = release.include?('redhatfips')
      end
      # A release tag looks like 1.el9 or 1.redhatfips9; the platform is what
      # follows the first dot.
      release_platforms = installed.grep(release_pattern).to_h do |name|
        tag = Facter::Core::Execution.execute("rpm -q --queryformat '%{RELEASE}' #{name}", on_fail: '')
        [name, tag.sub(%r{\A[^.]*\.}, '')]
      end
    else
      next nil
    end

    service = nil
    if Facter::Core::Execution.which('systemctl')
      service = {
        'running' => Facter::Core::Execution.execute('systemctl is-active puppet.service', on_fail: '').strip == 'active',
        'enabled' => Facter::Core::Execution.execute('systemctl is-enabled puppet.service', on_fail: '').strip == 'enabled',
      }
    end

    server_configured = nil
    if defined?(Puppet) && Puppet.respond_to?(:settings)
      begin
        settings = Puppet.settings
        server_configured = %i[server server_list].any? do |name|
          settings.set_by_config?(name) || (settings.respond_to?(:set_by_cli?) && settings.set_by_cli?(name))
        end || Puppet[:use_srv_records] == true
      rescue StandardError
        server_configured = nil
      end
    end

    {
      'agent_package' => agent_names.find { |name| installed.include?(name) },
      'release_packages' => present.grep(release_pattern).sort,
      'server_packages' => server_names.select { |name| installed.include?(name) },
      'held_packages' => (held & agent_names).sort,
      'fips_build' => fips_build,
      'release_platforms' => release_platforms,
      'service' => service,
      'server_configured' => server_configured,
    }
  end
end
