require 'spec_helper_acceptance'

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
