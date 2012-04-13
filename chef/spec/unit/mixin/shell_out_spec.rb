#
# Author:: Ho-Sheng Hsiao (hosh@opscode.com)
# Code derived from spec/unit/mixin/command_spec.rb
#
# Original header:
# Author:: Hongli Lai (hongli@phusion.nl)
# Copyright:: Copyright (c) 2009 Phusion
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

describe Chef::Mixin::ShellOut do
  include Chef::Mixin::ShellOut

  describe "#shell_out!", :unix_only do
    include Chef::Mixin::ShellOut

    let(:output) { StringIO.new }
    let(:logger) { Chef::Log.logger = Logger.new(output)  }

    it "should log the command's stderr and stdout output if the command failed" do
      Chef::Log.stub!(:level).and_return(:debug)
      begin
        shell_out!("sh -c 'echo hello; echo world >&2; false'")
        violated "Exception expected, but nothing raised."
      rescue => e
        e.message.should =~ /STDOUT: hello/
        e.message.should =~ /STDERR: world/
      end
    end

    context "when a process detaches but doesn't close STDOUT and STDERR [CHEF-584]" do
      it "should return successfully" do
        # CHEF-2916 might have added a slight delay here, or our CI infrastructure is burdened.
        # Bumping timeout from 2 => 4 -- btm
        proc do
          Timeout.timeout(4) do
            evil_forker="exit if fork; 10.times { sleep 1}"
            shell_out!("ruby -e '#{evil_forker}'")
          end
        end.should_not raise_error
      end
    end
  end

  describe '#with_systems_locale', :unix_only do
    include Chef::Mixin::ShellOut
    subject { with_systems_locale(args)[:environment]['LC_ALL'] }

    let(:system_locale) { ENV['LC_ALL'] }

    context 'without :environment set' do
      let(:args) { { } }
      it 'should set LC_ALL' do
        should eql(system_locale)
      end
    end

    context 'with :environment set' do
      let(:args) { { :cwd => '/tmp' } }

      it 'should set LC_ALL' do
        should eql(system_locale)
      end

      context 'with user-specified locale' do
        # Ask for a fake locale
        let(:args) { { :environment => { 'LC_ALL' => "en_US.Galactic-Standard-#{rand(10000)}" } } }

        it 'should override user-specified locale with the system locale' do
          should eql(system_locale)
        end
      end
    end
  end

  describe '#run_command_compatible_options' do
    subject { run_command_compatible_options(command_args) }
    let(:command_args) { [ cmd, options ] }
    let(:cmd) { "echo '#{rand(1000)}'" }

    let(:output) { StringIO.new }
    let(:capture_log_output) { Chef::Log.logger = Logger.new(output)  }
    let(:assume_deprecation_log_level) { Chef::Log.stub!(:level).and_return(:warn) }

    context 'without options' do
      let(:command_args) { [ cmd ] }

      it 'should not edit command args' do
        should eql(command_args)
      end
    end

    context 'without deprecated options' do
      let(:options) { { :environment => environment } }
      let(:environment) { { 'LC_ALL' => 'C' } }

      it 'should not edit command args' do
        should eql(command_args)
      end
    end

    def self.should_emit_deprecation_warning_about(old_option, new_option)
      it 'should emit a deprecation warning' do
        assume_deprecation_log_level and capture_log_output
        subject
        output.string.should match /DEPRECATION:/
        output.string.should match Regexp.escape(old_option.to_s)
        output.string.should match Regexp.escape(new_option.to_s)
      end
    end

    context 'with :command_log_level option' do
      let(:options) { { :command_log_level => command_log_level } }
      let(:command_log_level) { :warn }

      it 'should convert :command_log_level to :log_level' do
        should eql [ cmd, { :log_level => command_log_level } ]
      end

      should_emit_deprecation_warning_about :command_log_level, :log_level
    end

    context 'with :command_log_prepend option' do
      let(:options) { { :command_log_prepend => command_log_prepend } }
      let(:command_log_prepend) { 'PROVIDER:' }

      it 'should convert :command_log_prepend to :log_tag' do
        should eql [ cmd, { :log_tag => command_log_prepend } ]
      end

      should_emit_deprecation_warning_about :command_log_prepend, :log_tag
    end

    context "with 'command_log_level' option" do
      let(:options) { { 'command_log_level' => command_log_level } }
      let(:command_log_level) { :warn }

      it "should convert 'command_log_level' to :log_level" do
        should eql [ cmd, { :log_level => command_log_level } ]
      end

      should_emit_deprecation_warning_about :command_log_level, :log_level
    end
  end
end
