# frozen_string_literal: true

require 'spec_helper'

describe 'openvox_agent' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:debian) { os_facts[:os]['family'] == 'Debian' }
      let(:platform) do
        case os_facts[:os]['name']
        when 'Ubuntu' then "ubuntu#{os_facts[:os]['release']['full']}"
        when 'Debian' then "debian#{os_facts[:os]['release']['major']}"
        else "el#{os_facts[:os]['release']['major']}"
        end
      end

      let(:agent_state) do
        {
          'agent_package' => 'openvox-agent',
          'release_packages' => ['openvox8-release'],
          'server_packages' => [],
          'held_packages' => [],
        }
      end
      let(:facts) { os_facts.merge(aio_agent_version: '8.29.0', openvox_agent: agent_state) }

      context 'with defaults on an OpenVox 8 agent' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('openvox_agent::repo').that_comes_before('Class[openvox_agent::install]') }
        it { is_expected.to contain_class('openvox_agent::service').that_requires('Class[openvox_agent::install]') }
        it { is_expected.to contain_package('openvox-agent').with_ensure('present').with_install_options([]) }
        it { is_expected.to contain_package('openvox8-release') }

        it do
          is_expected.to contain_exec('openvox_agent restart after package change')
            .with_command('systemctl --no-block try-restart puppet.service')
            .with_refreshonly(true)
            .that_subscribes_to('Package[openvox-agent]')
        end

        it { is_expected.not_to contain_service('puppet') }

        if os_facts[:os]['family'] == 'Debian'
          it do
            is_expected.to contain_file("/var/cache/openvox_agent/openvox8-release-#{platform}.deb")
              .with_source("https://apt.voxpupuli.org/openvox8-release-#{platform}.deb")
          end

          it do
            is_expected.to contain_package('openvox8-release')
              .with_provider('dpkg')
              .with_source("/var/cache/openvox_agent/openvox8-release-#{platform}.deb")
          end

          it { is_expected.to contain_exec('openvox_agent apt-get update').that_subscribes_to('Package[openvox8-release]') }
        else
          it do
            is_expected.to contain_package('openvox8-release')
              .with_provider('rpm')
              .with_source("https://yum.voxpupuli.org/openvox8-release-el-#{os_facts[:os]['release']['major']}.noarch.rpm")
          end
        end
      end

      context 'when moving a Puppet 7 agent to openvox8' do
        let(:agent_state) do
          {
            'agent_package' => 'puppet-agent',
            'release_packages' => ['puppet7-release'],
            'server_packages' => [],
            'held_packages' => [],
          }
        end
        let(:facts) { os_facts.merge(aio_agent_version: '7.34.0', openvox_agent: agent_state) }
        let(:params) { { collection: 'openvox8' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('openvox8-release') }

        if os_facts[:os]['family'] == 'Debian'
          it do
            is_expected.to contain_package('puppet7-release')
              .with_ensure('purged')
              .that_comes_before('Package[openvox8-release]')
              .that_requires("File[/var/cache/openvox_agent/openvox8-release-#{platform}.deb]")
          end
        else
          it { is_expected.to contain_package('puppet7-release').with_ensure('absent').that_requires('Package[openvox8-release]') }
        end
      end

      context 'with a Puppet agent and no collection' do
        let(:agent_state) { super().merge('agent_package' => 'puppet-agent', 'release_packages' => ['puppet7-release']) }
        let(:facts) { os_facts.merge(aio_agent_version: '7.34.0', openvox_agent: agent_state) }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('openvox-agent') }
        it { is_expected.not_to contain_class('openvox_agent::repo') }
      end

      context 'when moving to openvox9' do
        let(:params) { { collection: 'openvox9', package_version: 'latest' } }

        it { is_expected.to contain_package('openvox-agent').with_ensure('latest') }
        it { is_expected.to contain_package('openvox9-release') }
        it { is_expected.to contain_package('openvox8-release').with_ensure(debian ? 'purged' : 'absent') }
      end

      context 'with a bare version' do
        let(:params) { { package_version: '8.29.0' } }

        if os_facts[:os]['family'] == 'Debian'
          it { is_expected.to contain_package('openvox-agent').with_ensure("8.29.0-1+#{platform}").with_install_options(['--allow-downgrades']) }
        else
          it { is_expected.to contain_package('openvox-agent').with_ensure("8.29.0-1.#{platform}").with_install_options([]) }
        end
      end

      context 'with a full package version' do
        let(:params) { { package_version: '9.0.0~rc4-1+debian12' } }

        it { is_expected.to contain_package('openvox-agent').with_ensure('9.0.0~rc4-1+debian12') }
      end

      context 'with mirrors' do
        let(:params) { { apt_source: 'https://mirror.example.com/apt', yum_source: 'https://mirror.example.com/yum' } }

        if os_facts[:os]['family'] == 'Debian'
          it { is_expected.to contain_file("/var/cache/openvox_agent/openvox8-release-#{platform}.deb").with_source(%r{\Ahttps://mirror\.example\.com/apt/}) }
        else
          it { is_expected.to contain_package('openvox8-release').with_source(%r{\Ahttps://mirror\.example\.com/yum/}) }
        end
      end

      context 'with manage_repo false' do
        let(:params) { { manage_repo: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('openvox_agent::repo') }
        it { is_expected.to contain_package('openvox-agent') }
      end

      context 'with the service managed' do
        let(:params) { { service_ensure: 'running', service_enable: true } }

        it { is_expected.to contain_service('puppet').with_ensure('running').with_enable(true) }
      end

      context 'with manage_service false' do
        let(:params) { { manage_service: false } }

        it { is_expected.not_to contain_exec('openvox_agent restart after package change') }
      end

      context 'on a server host' do
        let(:agent_state) { super().merge('server_packages' => ['openvox-server']) }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('openvox-agent') }
        it { is_expected.not_to contain_class('openvox_agent::repo') }
      end
    end
  end
end
