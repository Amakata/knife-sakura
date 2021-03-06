#
# Author:: HIGUCHI Daisuke (<d-higuchi@creationline.com>)
# Copyright:: Copyright (c) 2014 CREATIONLINE, INC.
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

require 'chef/knife'

class Chef
  class Knife
    module SakuraBase

      # :nodoc:
      # Would prefer to do this in a rational way, but can't be done b/c of
      # Mixlib::CLI's design :(
      def self.included(includer)
        includer.class_eval do

          deps do
            require 'fog'
            require 'readline'
            require 'chef/json_compat'
          end

          option :sakuracloud_credential_file,
            :long => "--sakuracloud-credential-file FILE",
            :description => "File containing Sakura Cloud credentials as used by sacloud cmdline tools",
            :proc => Proc.new { |key| Chef::Config[:knife][:sakuracloud_credential_file] = key }

          option :sakuracloud_api_token,
            :short => "-A Token",
            :long => "--sakuracloud-api-token Token",
            :description => "Your Sakura Cloud API Token",
            :proc => Proc.new { |key| Chef::Config[:knife][:sakuracloud_api_token] = key }

          option :sakuracloud_api_token_secret,
            :short => "-K SECRET",
            :long => "--sakuracloud-api-token-secret SECRET",
            :description => "Your Sakura Cloud API Token Secret",
            :proc => Proc.new { |key| Chef::Config[:knife][:sakuracloud_api_token_secret] = key }

        end
      end

      def connection
        @connection ||= begin
          connection = Fog::Compute.new(
            :provider => 'SakuraCloud',
            :sakuracloud_api_token => Chef::Config[:knife][:sakuracloud_api_token],
            :sakuracloud_api_token_secret => Chef::Config[:knife][:sakuracloud_api_token_secret],
          )
        end
      end

      def locate_config_value(key)
        key = key.to_sym
        config[key] || Chef::Config[:knife][key]
      end

      def msg_pair(label, value, color=:cyan)
        if value && !value.to_s.empty?
          puts "#{ui.color(label, color)}: #{value}"
        end
      end

      def is_image_windows?
        image_info = connection.images.get(@server.image_id)
        return image_info.platform == 'windows'
      end

      def validate!(keys=[:sakuracloud_api_token, :sakuracloud_api_token_secret])
        errors = []

        unless Chef::Config[:knife][:sakuracloud_credential_file].nil?
          unless (Chef::Config[:knife].keys & [:sakuracloud_api_token, :sakuracloud_api_token_secret]).empty?
            errors << "Either provide a credentials file or the access key and secret keys but not both."
          end
          # File format: JSON
          # "apiRoot": "",
          # "accessToken": ""
          # "accessTokenSecret": ""
          entries = JSON.load(*File.read(Chef::Config[:knife][:sakuracloud_credential_file]))
          Chef::Config[:knife][:sakuracloud_api_token] = entries['accessToken']
          Chef::Config[:knife][:sakuracloud_api_token_secret] = entries['accessTokenSecret']
        end

        keys.each do |k|
          pretty_key = k.to_s.gsub(/_/, ' ').gsub(/\w+/){ |w| (w =~ /(ssh)|(aws)/i) ? w.upcase  : w.capitalize }
          if Chef::Config[:knife][k].nil?
            errors << "You did not provide a valid '#{pretty_key}' value."
          end
        end

        if errors.each{|e| ui.error(e)}.any?
          exit 1
        end
      end
    end
  end
end
