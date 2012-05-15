#
# Author:: AJ Christensen (<aj@hjksolutions.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
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

require 'chef/mixin/shell_out'
require 'chef/provider/service'
require 'chef/provider/service/simple'
require 'chef/mixin/command'

class Chef
  class Provider
    class Service
      class Init < Chef::Provider::Service::Simple

        let(:init_command)  { "/etc/init.d/#{@new_resource.service_name}" }
        let(:start_command) { @new_resource.start_command || init_start }
        let(:stop_command)  { @new_resource.stop_command  || init_stop }

        let(:restart_command) { @new_resource.restart_command || ( supports_restart? ? init_restart : nil ) }
        let(:reload_command)  { @new_resource.reload_command  || ( supports_reload?  ? init_reload : nil ) }

        let(:init_start)   { "#{init_command} start" }
        let(:init_stop)    { "#{init_command} stop" }
        let(:init_restart) { "#{init_command} restart" }
        let(:init_reload)  { "#{init_command} reload" }

        let(:supports_restart?) { !!@new_resource.supports[:restart] }
        let(:supports_reload?)  { !!@new_resource.supports[:reload] }

      end
    end
  end
end
