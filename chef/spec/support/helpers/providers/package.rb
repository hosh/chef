module SpecHelpers
  module Providers
    module Package
      extend ActiveSupport::Concern

      included do
        include SpecHelpers::Provider

        let(:package_name) { 'chef' }
        let(:package_version) { '0.10.10' }

        let(:new_resource) { Chef::Resource::Package.new(package_name) }
        let(:current_resource) { Chef::Resource::Package.new(package_name) }
        let(:provider) { described_class.new(new_resource, run_context) }
        let(:installed_version) { package_version }
        let(:source_package_name) { package_name }
        let(:source_version) { package_version }

        let(:assume_new_resource) { provider.new_resource = new_resource }
        let(:assume_current_resource) { provider.current_resource = current_resource }
        let(:assume_source) { new_resource.source source_file }
        let(:assume_package_name_and_version) { provider.stub!(:package_name_and_version).and_return([source_package_name, source_version]) }
        let(:assume_source_version) { provider.should_receive(:source_version).and_return(source_version) }
        let(:assume_installed_version) { provider.stub!(:installed_version).and_return(installed_version) }

        let(:status) { mock("Status", :exitstatus => exitstatus, :stdout => stdout) }
        let(:exitstatus) { 0 }

        let(:stdout) { StringIO.new }
        let(:stderr) { StringIO.new }
        let(:stdin) { StringIO.new }

        let(:should_shell_out!) { provider.should_receive(:shell_out!).and_return(status) }
      end
    end
  end
end
