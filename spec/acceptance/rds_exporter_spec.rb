# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'prometheus rds exporter' do
  it 'rds_exporter works idempotently with no errors' do
    pp = 'include prometheus::rds_exporter'
    apply_manifest(pp, catch_failures: true)
    apply_manifest(pp, catch_changes: true)
  end

  describe 'default install' do
    describe service('prometheus-rds-exporter') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end
  
    describe port(9043) do
      it { is_expected.to be_listening.with('tcp6') }
    end
  end
end
