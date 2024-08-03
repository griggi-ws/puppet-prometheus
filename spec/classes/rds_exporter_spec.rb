# frozen_string_literal: true

require 'spec_helper'

describe 'prometheus::rds_exporter' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts.merge(os_specific_facts(facts))
      end

      context 'with version specified' do
        let(:params) do
          {
            version: '0.10.0',
            arch: 'amd64',
            os: 'Linux',
            bin_dir: '/usr/local/bin',
            install_method: 'url',
          }
        end

        describe 'with all defaults' do
          it { is_expected.to contain_class('prometheus') }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/usr/local/bin/rds_exporter').with('target' => '/opt/rds_exporter-0.10.0.linux-x86_64/prometheus-rds-exporter') }
          it { is_expected.to contain_prometheus__daemon('rds_exporter') }
          it { is_expected.to contain_user('rds-exporter') }
          it { is_expected.to contain_group('rds-exporter') }
          it { is_expected.to contain_service('rds_exporter') }
          it { is_expected.to contain_archive('/tmp/rds_exporter-0.10.0.tar.gz') }
          it { is_expected.to contain_file('/opt/rds_exporter-0.10.0.linux-x86_64/prometheus-rds-exporter') }
        end

        context 'with tls set in web-config.yml' do
          let(:params) do
            {
              web_config_content: {
                tls_server_config: {
                  cert_file: '/etc/rds_exporter/foo.cert',
                  key_file: '/etc/rds_exporter/foo.key'
                }
              }
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_file('/etc/rds_exporter_web-config.yml').with(ensure: 'file') }
          it { is_expected.to contain_prometheus__daemon('rds_exporter').with(options: '--config.file=/etc/rds-exporter.yaml --web.config.file=/etc/rds_exporter_web-config.yml') }
        end
      end

      context 'with custom config defined' do
        let(:params) do
          {
            config_content: {
              debug: true,
            }
          }
        end

        it { is_expected.to compile.with_all_deps }
        it {
          expect(subject).to contain_file('/etc/rds-exporter.yaml')
          verify_contents(catalogue, '/etc/rds-exporter.yaml', ['---', 'debug:', 'true'])
        }
        it { is_expected.to contain_prometheus__daemon('rds_exporter').with(options: '--config /etc/rds-exporter.yaml') }
      end

      context 'with env vars' do
        let :params do
          {
            env_vars: {
              blub: 'foobar'
            },
            env_file_path: '/cows'
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_prometheus__daemon('rds_exporter').with({ env_vars: { 'blub' => 'foobar' }, env_file_path: '/cows' }) }
      end
    end
  end
end
