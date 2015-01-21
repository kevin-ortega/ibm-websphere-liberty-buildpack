# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013-2015 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'liberty_buildpack/services'

# A module encapsulating all of the services components for the Liberty buildpack
module LibertyBuildpack::Services

  # An abstraction encapsulating the +VCAP_SERVICES+ of an application.
  #
  # A new instance of this type should be created once for the application.
  class VcapServices < Array

    def initialize(raw)
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      concat raw.values.flatten
    end

    # Compares the name, label, and tags of each service to the given +filter+.  The method returns +true+ if the
    # +filter+ matches exactly one service, +false+ otherwise.
    #
    # @param [Regexp, String] filter a +RegExp+ or +String+ to match against the name, label, and tags of the services
    # @param [String] required_credentials an optional list of keys or groups of keys, where at one key from the
    #                                      group, must exist in the credentials payload of the candidate service
    # @return [Boolean] +true+ if the +filter+ matches exactly one service with the required credentials, +false+
    #                   otherwise.
    def one_service?(filter, *required_credentials)
      candidates = select(&matcher(filter))
      match = false

      if candidates.empty?
        @logger.debug("Unable to resolve a single service plugin for service #{filter}. No matches exist")
      elsif candidates.one?
        if credentials?(candidates.first['credentials'], required_credentials)
          match = true
        else
          @logger.warn("A service with a name label or tag matching #{filter} was found, but was missing one of the required credentials #{required_credentials}")
        end
      else
        @logger.error("Unable to resolve a single service plugin for service #{filter}. Found potential matches of #{candidates}.")
        raise "Unable to resolve a single service plugin for service #{filter}. Multiple inexact matches exist."
      end

      match
    end

    # Compares the name, label, and tags of each service to the given +filter+.  The method returns the first service
    # that the +filter+ matches.  If no service matches, returns +nil+
    #
    # @param [Regexp, String] filter a +RegExp+ or +String+ to match against the name, label, and tags of the services
    # @return [Hash, nil] the first service that +filter+ matches.  If no service matches, returns +nil+.
    def find_service(filter)
      find(&matcher(filter))
    end

    private

    def credentials?(candidate, required_keys)
      required_keys.all? do |k|
        k.is_a?(Array) ? k.any? { |g| candidate.key?(g) } : candidate.key?(k)
      end
    end

    def matcher(filter)
      filter = Regexp.new(filter) unless filter.is_a?(Regexp)

      lambda do |service|
        (service['label'] == 'user-provided' && service['name'] =~ filter) || service['label'] =~ filter || !service['tags'].nil? && service['tags'].any? { |tag| tag =~ filter }
      end
    end
  end
end

