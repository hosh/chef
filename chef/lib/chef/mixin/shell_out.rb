#--
# Author:: Daniel DeLeo (<dan@opscode.com>)
# Copyright:: Copyright (c) 2010 Opscode, Inc.
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

require 'chef/shell_out'
require 'chef/config'

class Chef
  module Mixin
    module ShellOut

      def shell_out(*command_args)
        cmd = Mixlib::ShellOut.new(*command_args)
        if STDOUT.tty? && !Chef::Config[:daemon] && Chef::Log.debug?
          cmd.live_stream = STDOUT
        end
        cmd.run_command
        cmd
      end

      def shell_out_with_systems_locale(command, args={})
        shell_out command, with_systems_locale(args)
      end

      def shell_out!(*command_args)
        cmd = shell_out(*command_args)
        cmd.error!
        cmd
      end

      def shell_out_with_systems_locale!(command, args={})
        shell_out command, with_systems_locale(args)
      end

      def with_systems_locale(args={})
        args[:environment] ||= {}
        args[:environment]["LC_ALL"] = ENV["LC_ALL"]
        return args
      end
    end
  end
end
