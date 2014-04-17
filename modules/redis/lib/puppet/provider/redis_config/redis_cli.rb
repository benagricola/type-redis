require 'puppet'
require 'puppet/util/redis'

Puppet::Type.type(:redis_config).provide(:redis_cli) do
  confine :true => true
  defaultfor :feature => :posix

  mk_resource_methods

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def get_conn
    if ! @resource[:sock].nil?
      redisconn = Puppet::Util::Redis::Cli.new(@resource[:sock])
    else
      redisconn = Puppet::Util::Redis::Cli.new(@resource[:host],@resource[:port])
    end

    redisconn
  end

  def create
    redisconn = get_conn()

    @property_hash[:ensure] = :present
    @property_hash[:name] = @resource[:name]
    @property_hash[:mode] = @resource[:mode]
    @property_hash[:host] = @resource[:host]
    @property_hash[:port] = @resource[:port]
    @property_hash[:sock] = @resource[:sock]

    if @resource[:mode] == :standalone
      @property_hash[:settings] = @resource[:settings]
      @resource[:settings].each do |key,value|
        redisconn.set_redis_config(key,value)
      end
    else
      @property_hash[:masters] = @resource[:masters]
      @resource[:masters].each do |master_name,settings|
        settings.each do |key,value|
          redisconn.set_sentinel_master_config(master_name,key,value)
        end
      end
    end

    redisconn.config_rewrite()

    exists? ? (return true) : (return false)
  end

  def self.prefetch(resources)
    instances = []
    Puppet.debug "[prefetching...]"
    resources.each do |res_name,resource|

      if ! resource[:sock].nil?
        redisconn = Puppet::Util::Redis::Cli.new(resource[:sock])
      else
        redisconn = Puppet::Util::Redis::Cli.new(resource[:host],resource[:port])
      end

      if resource[:mode] == :standalone
        instance = new(
          :ensure   => :present,
          :host     => resource[:host],
          :port     => resource[:port],
          :sock     => resource[:sock],
          :mode     => :standalone,
          :settings => redisconn.get_redis_config()
        )
      else
        instance = new(
          :ensure   => :present,
          :host     => resource[:host],
          :port     => resource[:port],
          :sock     => resource[:sock],
          :mode     => :sentinel,
          :masters => redisconn.get_sentinel_masters()
        )
      end

      resource.provider = instance
      instances << instance
    end
    instances
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  def _flushModeRedis(redisconn)
    changed = false
    @property_flush[:settings].each do |key,value|
      if @property_flush[:settings][key] != @property_hash[:settings][key]
        redisconn.set_redis_config(key,value)
        @property_hash[:settings][key] = value
        changed = true
      end
    end
    # Force a config rewrite
    if changed
      redisconn.config_rewrite()
    end
  end

  def _flushModeSentinel(redisconn)
    @property_flush[:masters].each do |master_name,config|
      if !@property_hash[:masters].has_key?(master_name)
        redisconn.set_sentinel_monitor_master(master_name,config['ip'],config['port'],config['quorum'] || 2)
      end

      cur_master = @property_hash[:masters][master_name]

      master_recreated = false
      # Master by this name exists, lets make sure the IP:Port matches
      if cur_master['ip'] != config['ip'] or
        cur_master['port'] != config['port'] or
        cur_master['quorum'] != config['quorum']
        redisconn.forget_sentinel_monitor_master(master_name)
        redisconn.set_sentinel_monitor_master(master_name,config['ip'],config['port'],config['quorum'] || 2)
        master_recreated = true
      end

      current_config = cur_master || {}

      config['settings'].each do |key,value|
        if current_config[key] != value or master_recreated
          redisconn.set_sentinel_master_config(master_name,key,value)
        end
      end

      @property_hash[:masters][master_name] = config
    end
  end

  def flush
    redisconn = get_conn()

    if @property_flush
      if @resource[:mode] == :standalone
        _flushModeRedis(redisconn)
      elsif @resource[:mode] == :sentinel
        _flushModeSentinel(redisconn)
      end

      @property_flush = nil

    end
  end

  def settings=(settings)
    @property_flush[:settings] = settings
  end

  def masters=(masters)
    @property_flush[:masters] = masters
  end
end
