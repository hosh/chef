#
# Author:: AJ Christensen (<aj@hjksolutions.com>)
# Copyright:: Copyright (c) 2008 HJK Solutions, LLC
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe Chef::Provider::Service::Debian, "load_current_resource" do
  include SpecHelpers::Providers::Service

  before(:each) { provider.current_resource = current_resource }

  let(:ps_command) { 'fuuuu' }
  let(:stderr) { StringIO.new }
  let(:status) { mock("Status", :exitstatus => exitstatus, :stdout => stdout, :stderr => stderr) }
  let(:exitstatus) { 0 }

  let(:new_resource) { Chef::Resource::Service.new(service_name) }

  it "ensures /usr/sbin/update-rc.d is available" do
    File.should_receive(:exists?).with("/usr/sbin/update-rc.d").and_return(false)
    lambda { provider.assert_update_rcd_available }.should raise_error(Chef::Exceptions::Service)
  end

  describe "when update-rc.d shows the init script linked to rc*.d/" do

    let(:stdout) { StringIO.new(<<-UPDATE_RC_D_SUCCESS) }
Removing any system startup links for /etc/init.d/chef ...
  /etc/rc0.d/K20chef
  /etc/rc1.d/K20chef
  /etc/rc2.d/S20chef
  /etc/rc3.d/S20chef
  /etc/rc4.d/S20chef
  /etc/rc5.d/S20chef
  /etc/rc6.d/K20chef
UPDATE_RC_D_SUCCESS

    let(:stderr) { StringIO.new }

    before do
      provider.stub!(:assert_update_rcd_available)
      provider.stub!(:service_running?).and_return(true)
      provider.stub!(:shell_out!).and_return(status)
    end

    it "should say the service is enabled" do
      provider.service_currently_enabled?(provider.get_priority).should be_true
    end

    it "should store the 'enabled' state" do
      Chef::Resource::Service.stub!(:new).and_return(current_resource)
      provider.load_current_resource.should equal(current_resource)
      current_resource.enabled.should be_true
    end
  end

  context 'when enabling and disabling services' do
    {"Debian/Lenny and older" => {
        "linked" => {
          "stdout" => " Removing any system startup links for /etc/init.d/chef ...
     /etc/rc0.d/K20chef
     /etc/rc1.d/K20chef
     /etc/rc2.d/S20chef
     /etc/rc3.d/S20chef
     /etc/rc4.d/S20chef
     /etc/rc5.d/S20chef
     /etc/rc6.d/K20chef",
          "stderr" => ""
        },
        "not linked" => {
          "stdout" => " Removing any system startup links for /etc/init.d/chef ...",
          "stderr" => ""
        },
      },
      "Debian/Squeeze and earlier" => {
        "linked" => {
          "stdout" => "update-rc.d: using dependency based boot sequencing",
          "stderr" => "insserv: remove service /etc/init.d/../rc0.d/K20chef-client
insserv: remove service /etc/init.d/../rc1.d/K20chef-client
insserv: remove service /etc/init.d/../rc2.d/S20chef-client
insserv: remove service /etc/init.d/../rc3.d/S20chef-client
insserv: remove service /etc/init.d/../rc4.d/S20chef-client
insserv: remove service /etc/init.d/../rc5.d/S20chef-client
insserv: remove service /etc/init.d/../rc6.d/K20chef-client
insserv: dryrun, not creating .depend.boot, .depend.start, and .depend.stop"
        },
        "not linked" => {
          "stdout" => "update-rc.d: using dependency based boot sequencing",
          "stderr" => ""
        }
      }
    }.each do |model, streams|

      let(:status) { mock("Status", :exitstatus => 0, :stdout => stdout, :stderr => stderr) }

      describe "when update-rc.d shows the init script linked to rc*.d/" do
        before do
          provider.stub!(:assert_update_rcd_available)
          provider.stub!(:service_running?).and_return(true)
          provider.stub!(:shell_out!).and_return(status)
        end

        let(:stdout) { StringIO.new(streams["linked"]["stdout"]) }
        let(:stderr) { StringIO.new(streams["linked"]["stderr"]) }

        it "says the service is enabled" do
          provider.service_currently_enabled?(provider.get_priority).should be_true
        end

        it "stores the 'enabled' state" do
          Chef::Resource::Service.stub!(:new).and_return(current_resource)
          provider.load_current_resource.should equal(current_resource)
          current_resource.enabled.should be_true
        end

        it "stores the start/stop priorities of the service" do
          provider.load_current_resource
          expected_priorities = {"6"=>[:stop, "20"],
            "0"=>[:stop, "20"],
            "1"=>[:stop, "20"],
            "2"=>[:start, "20"],
            "3"=>[:start, "20"],
            "4"=>[:start, "20"],
            "5"=>[:start, "20"]}
          provider.current_resource.priority.should == expected_priorities
        end
      end

      describe "when using squeeze/earlier and update-rc.d shows the init script isn't linked to rc*.d" do
        before do
          provider.stub!(:assert_update_rcd_available)
          provider.stub!(:service_running?).and_return(true)
          provider.stub!(:shell_out!).and_return(status)
        end

        let(:stdout) { StringIO.new(streams["not linked"]["stdout"]) }
        let(:stderr) { StringIO.new(streams["not linked"]["stderr"]) }

        it "says the service is disabled" do
          provider.service_currently_enabled?(provider.get_priority).should be_false
        end

        it "stores the 'disabled' state" do
          Chef::Resource::Service.stub!(:new).and_return(current_resource)
          provider.load_current_resource.should equal(current_resource)
          current_resource.enabled.should be_false
        end
      end
    end
  end

  describe "when update-rc.d shows the init script isn't linked to rc*.d" do
    before do
      provider.stub!(:assert_update_rcd_available)
      provider.stub!(:service_running?).and_return(true)
      provider.stub!(:shell_out!).and_return(status)
    end

    let(:stdout) { StringIO.new(" Removing any system startup links for /etc/init.d/chef ...") }
    let(:stderr) { StringIO.new }

    it "says the service is disabled" do
      provider.service_currently_enabled?(provider.get_priority).should be_false
    end

    it "stores the 'disabled' state" do
      Chef::Resource::Service.stub!(:new).and_return(current_resource)
      provider.load_current_resource.should equal(current_resource)
      current_resource.enabled.should be_false
    end
  end

  context "when update-rc.d fails" do
    before(:each) { provider.stub!(:shell_out!).and_return(status) }
    let(:status) { mock("Status", :exitstatus => -1) }

    it "raises an error" do
      lambda { provider.service_currently_enabled?(provider.get_priority) }.should raise_error(Chef::Exceptions::Service)
    end
  end

  context "when enabling a service without priority" do
    it "should call update-rc.d 'service_name' defaults" do
      provider.should_receive(:shell_out!).with("/usr/sbin/update-rc.d -f #{new_resource.service_name} remove")
      provider.should_receive(:shell_out!).with("/usr/sbin/update-rc.d #{new_resource.service_name} defaults")
      provider.enable_service()
    end
  end

  context "when enabling a service with simple priority" do
    before(:each) { new_resource.priority(75) }

    it "should call update-rc.d 'service_name' defaults" do
      provider.should_receive(:shell_out!).with("/usr/sbin/update-rc.d -f #{new_resource.service_name} remove")
      provider.should_receive(:shell_out!).with("/usr/sbin/update-rc.d #{new_resource.service_name} defaults 75 25")
      provider.enable_service()
    end
  end

  context "when enabling a service with complex priorities" do
    before { new_resource.priority(2 => [:start, 20], 3 => [:stop, 55]) }

    it "should call update-rc.d 'service_name' defaults" do
      provider.should_receive(:shell_out!).with("/usr/sbin/update-rc.d -f #{new_resource.service_name} remove")
      provider.should_receive(:shell_out!).with("/usr/sbin/update-rc.d #{new_resource.service_name} start 20 2 . stop 55 3 . ")
      provider.enable_service()
    end
  end

  context "when disabling a service without a priority" do

    it "should call update-rc.d -f 'service_name' remove + stop with a default priority" do
      provider.should_receive(:shell_out!).with("/usr/sbin/update-rc.d -f #{new_resource.service_name} remove")
      provider.should_receive(:shell_out!).with("/usr/sbin/update-rc.d -f #{new_resource.service_name} stop 80 2 3 4 5 .")
      provider.disable_service()
    end
  end

  context "when disabling a service with simple priority" do
    before { new_resource.priority(75) }

    it "should call update-rc.d -f 'service_name' remove + stop with a specified priority" do
      provider.should_receive(:shell_out!).with("/usr/sbin/update-rc.d -f #{new_resource.service_name} remove")
      provider.should_receive(:shell_out!).with("/usr/sbin/update-rc.d -f #{new_resource.service_name} stop #{100 - new_resource.priority} 2 3 4 5 .")
      provider.disable_service()
    end
  end
end
