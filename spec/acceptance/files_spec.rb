require 'spec_helper_acceptance'

describe 'required packages' do
  required_git_repos = [
    file('/opt/graphite-web/.git'),
    file('/opt/carbon/.git'),
    file('/opt/whisper/.git'),
    file('/opt/statsd/.git'),
  ]
  required_git_repos.each do |git_directory|
    describe git_directory do
      it { should be_directory }
    end
  end

  required_graphite_directories = [
    file('/var/lib/graphite/storage/log'),
    file('/var/lib/graphite/storage/rrd'),
    file('/var/lib/graphite/storage/whisper'),
    file('/var/log/graphite'),
    file('/var/log/graphite/carbon-cache-a'),
  ]
  required_graphite_directories.each do |graphite_directory|
    describe graphite_directory do
      it { should be_directory }
      it { should be_owned_by 'www-data' }
      it { should be_grouped_into 'www-data' }
    end
  end

  describe file('/etc/logrotate.d/querylog') do
    its(:content) { should include '/var/log/graphite/carbon-cache-a/query.log' }
  end

  describe file('/etc/logrotate.d/listenerlog') do
    its(:content) { should include '/var/log/graphite/carbon-cache-a/listener.log' }
  end

  describe file('/etc/logrotate.d/createslog') do
    its(:content) { should include '/var/log/graphite/carbon-cache-a/creates.log' }
  end

  describe file('/etc/statsd/config.js') do
    it { should be_file }
    it { should be_owned_by 'statsd' }
    it { should be_grouped_into 'statsd' }
    its(:content) { should include 'graphitePort: 2003' }
  end

  describe file('/etc/graphite/carbon.conf') do
    it { should be_file }
    its(:content) { should include 'USER = www-data' }
  end

  describe file('/etc/graphite/graphite.wsgi') do
    it { should be_file }
    its(:content) { should include "sys.path.append('/var/lib/graphite/webapp')" }
  end

  describe file('/etc/graphite/storage-schemas.conf') do
    it { should be_file }
    its(:content) { should include '["carbon"]' }
  end

  describe file('/etc/graphite/storage-aggregation.conf') do
    it { should be_file }
    its(:content) { should include '[stats_counts]' }
  end

  describe file('/usr/local/lib/python2.7/dist-packages/graphite/local_settings.py') do
    it { should be_file }
    its(:content) { should include "CONF_DIR       = '/etc/graphite/'" }
  end

  describe file('/usr/local/bin/graphite-init-db.py') do
    it { should be_file }
    its(:content) { should include "management.call_command('syncdb', interactive=False)" }
  end

  describe file('/etc/graphite/admin.ini') do
    it { should be_file }
    it { should be_owned_by 'www-data' }
    it { should be_grouped_into 'www-data' }
    its(:content) { should include 'email=graphite@localhost' }
  end

  describe file('/etc/init.d/carbon-cache') do
    it { should be_file }
    its(:content) { should include '# Short-Description: Carbon Cache' }
  end

  describe file('/etc/init.d/statsd') do
    it { should be_file }
    its(:content) { should include '# Provides:          statsd' }
  end

  describe file('/etc/default/statsd') do
    it { should be_file }
    its(:content) { should include 'DAEMON_ARGS="/opt/statsd/stats.js /etc/statsd/config.js"' }
    its(:content) { should include 'CHDIR="/opt/statsd"' }
  end
end
