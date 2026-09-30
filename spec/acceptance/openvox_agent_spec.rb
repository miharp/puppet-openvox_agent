# frozen_string_literal: true

require 'spec_helper_acceptance'

# Beaker installs the agent from BEAKER_PUPPET_COLLECTION (openvox8 in CI).
# With BEAKER_PUPPET_COLLECTION=puppet7 the host starts on Puppet 7 and the
# spec first moves it to OpenVox 8.
#
# The stages build on each other, so the examples depend on running in
# order. RSpec runs a group's own examples before its nested groups, and
# it_behaves_like is a nested group, so each stage's checks sit in a group
# defined after the apply.
FROM_PUPPET = ENV.fetch('BEAKER_PUPPET_COLLECTION', 'openvox8').start_with?('puppet')

def puppet_version
  shell('/opt/puppetlabs/bin/puppet --version').stdout.strip
end

describe 'openvox_agent' do
  before(:all) do
    # A setting of the operator's, to show puppet.conf survives every move.
    shell('/opt/puppetlabs/bin/puppet config set --section agent runinterval 1234')
  end

  context 'with defaults' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) { "class { 'openvox_agent': }" }
    end

    describe 'afterwards' do
      it 'leaves the agent where it is' do
        expect(puppet_version).to match(FROM_PUPPET ? %r{\A7\.} : %r{\A8\.})
      end
    end
  end

  if FROM_PUPPET
    context 'when moving a Puppet 7 agent to openvox8' do
      it_behaves_like 'an idempotent resource' do
        let(:manifest) { "class { 'openvox_agent': collection => 'openvox8' }" }
      end

      describe 'afterwards' do
        it { expect(puppet_version).to match(%r{\A8\.}) }

        it 'replaces the Puppet agent and release packages' do
          expect(package('openvox-agent')).to be_installed
          expect(package('puppet-agent')).not_to be_installed
          expect(package('puppet7-release')).not_to be_installed
        end
      end
    end
  end

  context 'when moving to openvox9' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) { "class { 'openvox_agent': collection => 'openvox9', package_version => 'latest' }" }
    end

    describe 'afterwards' do
      it { expect(puppet_version).to match(%r{\A9\.}) }

      it 'replaces the release package' do
        expect(package('openvox9-release')).to be_installed
        expect(package('openvox8-release')).not_to be_installed
      end

      it 'keeps puppet.conf through every move' do
        expect(shell('/opt/puppetlabs/bin/puppet config print --section agent runinterval').stdout.strip).to eq('1234')
      end
    end
  end
end
