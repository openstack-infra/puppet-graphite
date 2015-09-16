require 'spec_helper_acceptance'

describe 'puppet-graphite module' do
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
    apply_manifest(default_puppet_module, catch_failures: true)
    apply_manifest(default_puppet_module, catch_changes: true)
  end

  it 'should enable the services' do
    apply_manifest(postconditions_puppet_module, catch_failures: true)
  end
end
