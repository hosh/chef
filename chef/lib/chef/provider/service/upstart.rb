#
# Author:: Bryan McLellan <btm@loftninjas.org>
# Copyright:: Copyright (c) 2010 Bryan McLellan
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

require 'chef/provider/service'
require 'chef/provider/service/simple'
require 'chef/util/file_edit'

class Chef
  class Provider
    class Service
      class Upstart < Chef::Provider::Service::Simple
        attr_reader :upstart_job_dir, :upstart_conf_suffix

        UPSTART_STATE_FORMAT = /\w+ \(?(\w+)\)?[\/ ](\w+)/

        # Upstart does more than start or stop a service, creating multiple 'states' [1] that a service can be in.
        # In chef, when we ask a service to start, we expect it to have started before performing the next step
        # since we have top down dependencies. Which is to say we may follow witha resource next that requires
        # that service to be running. According to [2] we can trust that sending a 'goal' such as start will not
        # return until that 'goal' is reached, or some error has occured.
        #
        # [1] http://upstart.ubuntu.com/wiki/JobStates
        # [2] http://www.netsplit.com/2008/04/27/upstart-05-events/

        def initialize(new_resource, run_context)
          # TODO: re-evaluate if this is needed after integrating cookbook fix
          raise ArgumentError, "run_context cannot be nil" unless run_context
          super

          run_context.node

          platform, version = Chef::Platform.find_platform_and_version(run_context.node)
          if platform == "ubuntu" && (8.04..9.04).include?(version.to_f)
            @upstart_job_dir = "/etc/event.d"
            @upstart_conf_suffix = ""
          else
            @upstart_job_dir = "/etc/init"
            @upstart_conf_suffix = ".conf"
          end
        end

        def load_current_resource
          @current_resource = Chef::Resource::Service.new(@new_resource.name)
          @current_resource.service_name(@new_resource.service_name)

          @current_resource.running service_running?
          @current_resource.enabled service_enabled?
          @current_resource
        end

        def start_service
          # Calling start on a service that is already started will return 1
          # Our 'goal' when we call start is to ensure the service is started
          if @current_resource.running
            Chef::Log.debug("#{@new_resource} already running, not starting")
          else
            if @new_resource.start_command
              super
            else
              shell_out_with_systems_locale!("/sbin/start #{@new_resource.service_name}")
            end
          end
        end

        def stop_service
          # Calling stop on a service that is already stopped will return 1
          # Our 'goal' when we call stop is to ensure the service is stopped
          unless @current_resource.running
            Chef::Log.debug("#{@new_resource} not running, not stopping")
          else
            if @new_resource.stop_command
              super
            else
              shell_out_with_systems_locale!("/sbin/stop #{@new_resource.service_name}")
            end
          end
        end

        def restart_service
          if @new_resource.restart_command
            super
          # Upstart always provides restart functionality so we don't need to mimic it with stop/sleep/start.
          # Older versions of upstart would fail on restart if the service was currently stopped, check for that. LP:430883
          else @new_resource.supports[:restart]
            if @current_resource.running
              shell_out_with_systems_locale!("/sbin/restart #{@new_resource.service_name}")
            else
              start_service
            end
          end
        end

        def reload_service
          if @new_resource.reload_command
            super
          else
            # upstart >= 0.6.3-4 supports reload (HUP)
            shell_out_with_systems_locale!("/sbin/reload #{@new_resource.service_name}")
          end
        end

        # https://bugs.launchpad.net/upstart/+bug/94065

        def enable_service
          Chef::Log.debug("#{@new_resource} upstart lacks inherent support for enabling services, editing job config file")
          conf = Chef::Util::FileEdit.new("#{@upstart_job_dir}/#{@new_resource.service_name}#{@upstart_conf_suffix}")
          conf.search_file_replace(/^#start on/, "start on")
          conf.write_file
        end

        def disable_service
          Chef::Log.debug("#{@new_resource} upstart lacks inherent support for disabling services, editing job config file")
          conf = Chef::Util::FileEdit.new("#{@upstart_job_dir}/#{@new_resource.service_name}#{@upstart_conf_suffix}")
          conf.search_file_replace(/^start on/, "#start on")
          conf.write_file
        end

        def upstart_state
          command = "/sbin/status #{@new_resource.service_name}"
          status = shell_out!(command)

          # rsyslog stop/waiting
          # service goal/state
          # OR
          # rsyslog (stop) waiting
          # service (goal) state
          status.stdout.each_line do |line|
            line =~ UPSTART_STATE_FORMAT
            data = Regexp.last_match
            return data[2]
          end
        end

        def service_running?
          # Get running/stopped state
          # We do not support searching for a service via ps when using upstart since status is a native
          # upstart function. We will however support status_command in case someone wants to do something special.
          if @new_resource.status_command
            Chef::Log.debug("#{@new_resource} you have specified a status command, running..")

            begin
              if shell_out_with_systems_locale!(@new_resource.status_command) == 0
                return true
              end
            rescue Mixlib::ShellOut::ShellCommandFailed
              return false
            end
          else
            begin
              if upstart_state == "running"
                return true
              else
                return false
              end
            rescue Mixlib::ShellOut::ShellCommandFailed
              return false
              nil
            end
          end
        end

        def service_enabled?
          # Get enabled/disabled state by reading job configuration file
          unless ::File.exists?("#{@upstart_job_dir}/#{@new_resource.service_name}#{@upstart_conf_suffix}")
            Chef::Log.debug("#{@new_resource} did not find #{@upstart_job_dir}/#{@new_resource.service_name}#{@upstart_conf_suffix}")
            return false
          end

          Chef::Log.debug("#{@new_resource} found #{@upstart_job_dir}/#{@new_resource.service_name}#{@upstart_conf_suffix}")
          ::File.open("#{@upstart_job_dir}/#{@new_resource.service_name}#{@upstart_conf_suffix}",'r') do |file|
            while line = file.gets
              case line
              when /^start on/
                Chef::Log.debug("#{@new_resource} enabled: #{line.chomp}")
                return true
              when /^#start on/
                Chef::Log.debug("#{@new_resource} disabled: #{line.chomp}")
                return false
              end
            end
          end
        end

      end
    end
  end
end
