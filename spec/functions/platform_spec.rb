# frozen_string_literal: true

require 'spec_helper'

describe 'openvox_agent::platform' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:expected) do
        case os_facts[:os]['name']
        when 'Ubuntu' then "ubuntu#{os_facts[:os]['release']['full']}"
        when 'Debian' then "debian#{os_facts[:os]['release']['major']}"
        else "el#{os_facts[:os]['release']['major']}"
        end
      end

      it { is_expected.to run.with_params.and_return(expected) }
    end
  end
end
