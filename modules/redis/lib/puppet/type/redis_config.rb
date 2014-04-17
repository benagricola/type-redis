Puppet::Type.newtype(:redis_config) do
    desc 'Provides online reconfiguration of redis (and sentinel) server'

    newparam(:name, :namevar => true) do
      desc 'The Redis or Sentinel instance name, must be unique.'
    end

    newproperty(:settings) do
      defaultto {}
    end

    newproperty(:masters) do
      defaultto {}
    end

    newproperty(:mode) do
      desc 'The Mode of this redis server instance.'
      newvalues(:standalone,:sentinel)
      defaultto :standalone
    end

    newparam(:sock) do
      desc 'The unix socket used to connect to this instance.'
      defaultto ""
    end

    newparam(:host) do
      desc 'The host used to connect to this instance.'
      defaultto "127.0.0.1"
      newvalues(/\w+/)
    end

    newparam(:port) do
      desc 'The port used to connect to this instance.'
      defaultto 6379

      validate do |port|
        fail('Port is not in the range 1-65535') unless port.to_i >= 1 and
          port.to_i <= 65535
      end
    end
end

Puppet::Type.type(:redis_config)
