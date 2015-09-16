require 'spec_helper_acceptance'

describe 'puppet-graphite module', :if => ['debian', 'ubuntu'].include?(os[:family]) do
  def pp_path
    base_path = File.dirname(__FILE__)
    File.join(base_path, 'fixtures')
  end

  def default_puppet_module
    module_path = File.join(pp_path, 'default.pp')
    File.read(module_path)
  end

  def postconditions_puppet_module
    module_path = File.join(pp_path, 'postconditions.pp')
    File.read(module_path)
  end

  it 'should work with no errors' do
    apply_manifest(default_puppet_module, catch_failures: true)
  end

  it 'should be idempotent' do
    apply_manifest(default_puppet_module, catch_changes: true)
  end

  it 'should enable the services' do
    apply_manifest(postconditions_puppet_module, catch_failures: true)
  end

  describe 'required packages' do
    required_packages = [
      package('python-django'),
      package('python-django-tagging'),
      package('python-cairo'),
      package('nodejs')
    ]

    required_packages.each do |package|
      describe package do
        it { should be_installed }
      end
    end
  end

  describe 'required files' do
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

  describe 'required services' do
    describe service('carbon-cache') do
      it { should be_enabled }
    end

    describe service('statsd') do
      it { should be_enabled }
    end
  end

  describe cron do
    it { should have_entry('0 2 * * * find /var/lib/graphite/storage/whisper -type f -mtime +270 -name \\\\*.wsp -delete; find /var/lib/graphite/storage/whisper -depth -type d -empty -delete > /dev/null').with_user('root') }
  end
end
