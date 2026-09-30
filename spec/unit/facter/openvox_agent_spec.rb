# frozen_string_literal: true

require 'spec_helper'

describe 'openvox_agent fact' do
  subject(:fact) { Facter.fact(:openvox_agent).value }

  before do
    Facter.clear
    allow(Facter.fact(:kernel)).to receive(:value).and_return('Linux')
  end

  after { Facter.clear }

  context 'with dpkg' do
    before do
      allow(Facter::Core::Execution).to receive(:which).with('dpkg-query').and_return('/usr/bin/dpkg-query')
      allow(Facter::Core::Execution).to receive(:execute).with(%r{\Adpkg-query}, on_fail: '').and_return(<<~DPKG)
        openvox8-release ii
        puppet7-release rc
        openvox7-release un
        puppet-tools-release ii
        openvox-agent hi
        openvox-server ii
        openvoxdb rc
      DPKG
      allow(Facter::Core::Execution).to receive(:execute).with('apt-mark showhold', on_fail: '').and_return("openvox-agent\ncurl\n")
    end

    it 'reports the installed agent, release packages including removed ones, server packages and holds' do
      expect(fact).to eq(
        'agent_package' => 'openvox-agent',
        'release_packages' => %w[openvox8-release puppet7-release],
        'server_packages' => ['openvox-server'],
        'held_packages' => ['openvox-agent'],
      )
    end
  end

  context 'with rpm' do
    before do
      allow(Facter::Core::Execution).to receive(:which).with('dpkg-query').and_return(nil)
      allow(Facter::Core::Execution).to receive(:which).with('rpm').and_return('/usr/bin/rpm')
      allow(Facter::Core::Execution).to receive(:execute).with(%r{\Arpm -qa}, on_fail: '').and_return("puppet7-release\npuppet-agent\nbash\n")
      allow(File).to receive(:readable?).and_call_original
      allow(File).to receive(:readable?).with('/etc/dnf/plugins/versionlock.list').and_return(true)
      allow(File).to receive(:readable?).with('/etc/yum/pluginconf.d/versionlock.list').and_return(false)
      allow(File).to receive(:readlines).with('/etc/dnf/plugins/versionlock.list').and_return(["# comment\n", "puppet-agent-0:7.34.0-1.el9.*\n"])
    end

    it 'reports the installed agent, release packages and versionlocked agent packages' do
      expect(fact).to eq(
        'agent_package' => 'puppet-agent',
        'release_packages' => ['puppet7-release'],
        'server_packages' => [],
        'held_packages' => ['puppet-agent'],
      )
    end
  end

  context 'without dpkg or rpm' do
    before do
      allow(Facter::Core::Execution).to receive(:which).and_return(nil)
    end

    it { expect(fact).to be_nil }
  end
end
