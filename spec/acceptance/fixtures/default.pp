class { '::graphite':
  graphite_admin_user     => 'graphite',
  graphite_admin_email    => 'graphite@localhost',
  graphite_admin_password => '12345',
  vhost_name              => '*',
}
