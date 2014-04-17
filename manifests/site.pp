node default {
  redis_config { 'shard_a_master':
    settings => {
      maxmemory => 1073741829,
    },
    mode => standalone,
    sock => '/var/run/redis/redis-server.sock'
  }
  
  redis_config { 'blah_sentinel':
    masters => {
      redis_master_1 => {
        ip     =>  '127.0.0.1',
        port     => 6379,
        quorum   => 4,
        settings => {
          'down-after-milliseconds' => 5000,
        },
      }
    },
    mode => sentinel,
    sock => '/var/run/redis/redis-sentinel.sock'
  }
}
