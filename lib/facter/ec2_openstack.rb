begin
  require 'facter/ec2/rest'

  # Patch Facter::EC2::Base to have a longer timeout
  module Facter::EC2
    class Base
      def reachable?(retry_limit = 3)
        timeout = 20
        able_to_connect = false
        attempts = 0

        begin
          Timeout.timeout(timeout) do
            open(@baseurl).read
          end
          able_to_connect = true
        rescue OpenURI::HTTPError => e
          if e.message.match /404 Not Found/i
            able_to_connect = false
          else
            attempts = attempts + 1
            retry if attempts < retry_limit
          end
        rescue Timeout::Error
          attempts = attempts + 1
          retry if attempts < retry_limit
        rescue *CONNECTION_ERRORS
          attempts = attempts + 1
          retry if attempts < retry_limit
        end

        able_to_connect
      end
    end
  end

  Facter.define_fact(:ec2_metadata) do
    define_resolution(:openstack_rest) do
      confine do
        Facter.value(:manufacturer) == 'OpenStack Foundation'
      end

      @querier = Facter::EC2::Metadata.new
      confine do
        @querier.reachable?
      end

      setcode do
        @querier.fetch
      end
    end
  end

  Facter.define_fact(:ec2_userdata) do
    define_resolution(:openstack_rest) do
      confine do
        Facter.value(:manufacturer) == 'OpenStack Foundation'
      end

      @querier = Facter::EC2::Userdata.new
      confine do
        @querier.reachable?
      end

      setcode do
        @querier.fetch
      end
    end
  end

  if (ec2_metadata = Facter.value(:ec2_metadata))
    ec2_facts = Facter::Util::Values.flatten_structure("ec2", ec2_metadata)
    ec2_facts.each_pair do |factname, factvalue|
      Facter.add(factname, :value => factvalue)
    end
  end
rescue LoadError => detail
  # This means we're running on an old enough version of facter where the ec2 facts aren't broken
  Facter.debug "Unable to load module for openstack ec2 facts, assuming working version of facter: #{detail.message}"
end