require 'spec_helper_acceptance'

describe 'required services', :if => ['debian', 'ubuntu'].include?(os[:family]) do
  describe service('carbon-cache') do
    it { should be_enabled }
  end

  describe service('statsd') do
    it { should be_enabled }
  end
end
