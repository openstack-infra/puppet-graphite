exec { 'starting carbon-cache service':
  command => '/etc/init.d/carbon-cache start',
}

exec { 'starting statsd service':
  command => '/etc/init.d/statsd start'
}
