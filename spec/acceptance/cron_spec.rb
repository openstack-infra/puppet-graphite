require 'spec_helper_acceptance'

describe cron, :if => ['debian', 'ubuntu'].include?(os[:family]) do
  it { should have_entry('0 2 * * * find /var/lib/graphite/storage/whisper -type f -mtime +270 -name \\\\*.wsp -delete; find /var/lib/graphite/storage/whisper -depth -type d -empty -delete > /dev/null').with_user('root') }
end
