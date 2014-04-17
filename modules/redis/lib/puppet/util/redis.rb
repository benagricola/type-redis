module Puppet::Util::Redis
  include Puppet::Util::Execution

  class Cli

    @conn = nil

    def initialize(*args)
      if args.length < 1
        Puppet.debug('RedisCli must be called with a socket path or host, port combination!')
        return nil
      end

      @conn = conn_args(args)
    end

    def conn_args(*args)
      if args.length > 1
        ['-h',args[0],'-p',args[1]]
      else
        ['-s',args[0]]
      end
    end

    def redis_cmd(cmd)
      ret = Puppet::Util::Execution.execute(['redis-cli'] + @conn + cmd,:failonfail => true)
      if ret =~ /^ERR (.*)$/
        raise Puppet::ExecutionFailure, "redis_cmd had an error: #{$1}"
      end

      return ret.split("\n")
    end

    def redis_cmd_pairs(cmd)
      out = {}
      outlist = []
      redis_cmd(cmd).each_slice(2) do |pair|

        # If we see an existing key then this is a new record, rotate
        if out.has_key?(pair[0])
          outlist << out
          out = {}
        end

        out[pair[0]] = pair[1]
      end

      outlist << out

      (outlist.length > 1)? outlist : outlist[0]
    end

    def get_info()
      out = {}
      redis_cmd(['info']).map do |pair|
        key, value = pair.split(':')
        if !value.nil?
          out[key] = value.strip
        end
      end

      out
    end

    def config_rewrite()
      output = redis_cmd(['config','rewrite'])
    end

    def get_sentinel_masters()
      out = {}
      redis_cmd_pairs(['sentinel','masters']).each do |master|
        out[master['name']] = master
      end
      out
    end

    def set_sentinel_monitor_master(master,host,port,quorum)
      redis_cmd_pairs(['sentinel','monitor',master,host,port,quorum])
    end

    def forget_sentinel_monitor_master(master)
      redis_cmd_pairs(['sentinel','remove',master])
    end

    def set_sentinel_master_config(master,key,value)
      redis_cmd_pairs(['sentinel','set',master,key,value])
    end

    def set_redis_config(key,value)
      redis_cmd(['config','set',key,value])
    end

    def get_redis_config_keys()
      redis_cmd_pairs(['config','get','*']).keys
    end

    def get_redis_config(key = '*')
      redis_cmd_pairs(['config','get',key])
    end
  end
end
