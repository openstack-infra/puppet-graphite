# == Class: graphite
#
class graphite(
  $graphite_admin_email,
  $graphite_admin_password,
  $graphite_admin_user,
  $storage_schemas = [
    {
      'name'       => 'carbon',
      'pattern'    => '^carbon\.',
      'retentions' => '60:90d',
    },
    {
      'name'       => 'stats',
      'pattern'    => '^stats.*',
      'retentions' => '10s:8h,60s:7d,1h:1y,1d:5y',
    },
    {
      'name'       => 'default',
      'pattern'    => '.*',
      'retentions' => '60:90d',
    }
  ],
  $vhost_name      = $::fqdn,
  # Have statsd listen on '::' which, thanks to dual-stack,
  # gets ipv4 and ipv6 connections.
  $statsd_ipv6_listen = true,
) {
  $packages = [ 'python-django',
                'python-django-tagging',
                'python-cairo',
                'nodejs',
                'python-tz' ]

  include ::httpd
  include ::pip

  include ::httpd::mod::wsgi

  # The Apache mod_version module only needs to be enabled on Ubuntu 12.04
  # as it comes compiled and enabled by default on newer OS, including CentOS
  if !defined(Httpd::Mod['version']) and $::operatingsystem == 'Ubuntu' and $::operatingsystemrelease == '12.04' {
    httpd::mod { 'version': ensure => present }
  }

  package { $packages:
    ensure => present,
  }

  if $::operatingsystemrelease == '12.04' {
    # pin version because of https://github.com/graphite-project/graphite-web/issues/650
    $graphite_rev = '7f8c33da809e2938df55c1ff57ab5329d8d7b878'
  }
  else {
    $graphite_rev = '0.9.x'
  }

  vcsrepo { '/opt/graphite-web':
    ensure   => present,
    provider => git,
    revision => $graphite_rev,
    source   => 'https://github.com/graphite-project/graphite-web.git',
  }

  # Install data to /usr/local/share because it's example data and
  # we don't want pip to know about our real data location
  exec { 'install_graphite_web' :
    command     => 'pip install --install-option="--install-scripts=/usr/local/bin" --install-option="--install-lib=/usr/local/lib/python2.7/dist-packages" --install-option="--install-data=/usr/local/share/graphite" /opt/graphite-web',
    path        => '/usr/local/bin:/usr/bin:/bin',
    refreshonly => true,
    subscribe   => Vcsrepo['/opt/graphite-web'],
    require     => [Exec['install_carbon'],
                    File['/var/lib/graphite/storage']]
  }

  vcsrepo { '/opt/carbon':
    ensure   => latest,
    provider => git,
    revision => '0.9.x',
    source   => 'https://github.com/graphite-project/carbon.git',
  }

  # Install data to /usr/local/share because it's example data and
  # we don't want pip to know about our real data location
  exec { 'install_carbon' :
    command     => 'pip install --install-option="--install-scripts=/usr/local/bin" --install-option="--install-lib=/usr/local/lib/python2.7/dist-packages" --install-option="--install-data=/usr/local/share/graphite" /opt/carbon',
    path        => '/usr/local/bin:/usr/bin:/bin',
    refreshonly => true,
    subscribe   => Vcsrepo['/opt/carbon'],
    require     => [Exec['install_whisper'],
                    File['/var/lib/graphite/storage']]
  }

  vcsrepo { '/opt/whisper':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => 'https://github.com/graphite-project/whisper.git',
  }

  exec { 'install_whisper' :
    command     => 'pip install /opt/whisper',
    path        => '/usr/local/bin:/usr/bin:/bin/',
    refreshonly => true,
    subscribe   => Vcsrepo['/opt/whisper'],
  }

  user { 'statsd':
    ensure     => present,
    home       => '/home/statsd',
    shell      => '/bin/bash',
    gid        => 'statsd',
    managehome => true,
    require    => Group['statsd'],
  }

  group { 'statsd':
    ensure => present,
  }

  file { '/var/lib/graphite':
    ensure  => directory,
  }

  file { '/var/lib/graphite/webapp':
    ensure  => directory,
    require => [File['/var/lib/graphite']],
  }

  file { '/var/lib/graphite/webapp/content':
    ensure  => directory,
    source  => '/opt/graphite-web/webapp/content',
    recurse => true,
    require => [File['/var/lib/graphite/webapp'],
                Vcsrepo['/opt/graphite-web']],
  }

  file { '/var/lib/graphite/storage':
    ensure  => directory,
    owner   => 'www-data',
    group   => 'www-data',
    require => [Class['httpd'],
                File['/var/lib/graphite']]
  }

  file { '/var/lib/graphite/storage/log':
    ensure  => directory,
    owner   => 'www-data',
    group   => 'www-data',
    require => File['/var/lib/graphite/storage'],
  }

  file { '/var/lib/graphite/storage/rrd':
    ensure  => directory,
    owner   => 'www-data',
    group   => 'www-data',
    require => File['/var/lib/graphite/storage'],
  }

  file { '/var/lib/graphite/storage/whisper':
    ensure  => directory,
    owner   => 'www-data',
    group   => 'www-data',
    require => File['/var/lib/graphite/storage'],
  }

  file { '/var/log/graphite':
    ensure  => directory,
    owner   => 'www-data',
    group   => 'www-data',
    require => Class['httpd'],
  }

  file { '/var/log/graphite/carbon-cache-a':
    ensure  => directory,
    owner   => 'www-data',
    group   => 'www-data',
    require => File['/var/log/graphite'],
  }

  include ::logrotate
  logrotate::file { 'graphite-carbon':
    log     => '/var/log/graphite/carbon-cache-a/*.log',
    options => [
      'compress',
      'nocreate',
      'missingok',
      'rotate 7',
      'daily',
      'notifempty',
      'sharedscripts',
    ],
  }

  file { '/etc/graphite':
    ensure  => directory,
  }

  exec { 'graphite_sync_db':
    user    => 'www-data',
    command => 'python /usr/local/bin/graphite-init-db.py /etc/graphite/admin.ini',
    cwd     => '/usr/local/lib/python2.7/dist-packages/graphite',
    path    => '/bin:/usr/bin',
    onlyif  => 'test ! -f /var/lib/graphite/storage/graphite.db',
    require => [ Exec['install_graphite_web'],
      File['/var/lib/graphite'],
      Class['httpd'],
      File['/usr/local/lib/python2.7/dist-packages/graphite/local_settings.py'],
      File['/usr/local/bin/graphite-init-db.py'],
      File['/etc/graphite/admin.ini']],
  }

  ::httpd::vhost { $vhost_name:
    port     => 80,
    priority => '50',
    docroot  => '/var/lib/graphite/webapp',
    template => 'graphite/graphite.vhost.erb',
  }

  if !defined(Httpd::Mod['headers']) {
    ::httpd::mod { 'headers':
      ensure => present,
    }
  }

  vcsrepo { '/opt/statsd':
    ensure   => latest,
    provider => git,
    source   => 'https://github.com/etsy/statsd.git',
  }

  file { '/etc/statsd':
    ensure  => directory,
  }

  file { '/etc/statsd/config.js':
    owner   => 'statsd',
    group   => 'statsd',
    mode    => '0444',
    content => template('graphite/config.js.erb'),
    require => File['/etc/statsd'],
  }

  file { '/etc/graphite/carbon.conf':
    mode    => '0444',
    content => template('graphite/carbon.conf.erb'),
    require => File['/etc/graphite'],
  }

  file { '/etc/graphite/graphite.wsgi':
    mode    => '0444',
    content => template('graphite/graphite.wsgi.erb'),
    require => File['/etc/graphite'],
  }

  file { '/etc/graphite/storage-schemas.conf':
    mode    => '0444',
    content => template('graphite/storage-schemas.conf.erb'),
    require => File['/etc/graphite'],
  }

  file { '/etc/graphite/storage-aggregation.conf':
    mode    => '0444',
    content => template('graphite/storage-aggregation.conf.erb'),
    require => File['/etc/graphite'],
  }

  file { '/usr/local/lib/python2.7/dist-packages/graphite/local_settings.py':
    mode    => '0444',
    content => template('graphite/local_settings.py.erb'),
    require => Exec['install_graphite_web'],
  }

  file { '/usr/local/bin/graphite-init-db.py':
    mode   => '0555',
    source => 'puppet:///modules/graphite/graphite-init-db.py'
  }

  file { '/etc/graphite/admin.ini':
    mode    => '0400',
    owner   => 'www-data',
    group   => 'www-data',
    content => template('graphite/admin.ini'),
    require => [ File['/etc/graphite'],
      Class['httpd']],
  }

  file { '/etc/init.d/carbon-cache':
    mode   => '0555',
    source => 'puppet:///modules/graphite/carbon-cache.init'
  }

  file { '/etc/init.d/statsd':
    mode   => '0555',
    source => 'puppet:///modules/graphite/statsd.init'
  }

  file { '/etc/default/statsd':
    mode   => '0444',
    source => 'puppet:///modules/graphite/statsd.default'
  }

  service { 'carbon-cache':
    name       => 'carbon-cache',
    enable     => true,
    hasrestart => true,
    require    => [File['/etc/init.d/carbon-cache'],
                    File['/etc/graphite/carbon.conf'],
                    Exec['install_carbon']],
  }

  service { 'statsd':
    name       => 'statsd',
    enable     => true,
    hasrestart => true,
    require    => [File['/etc/init.d/statsd'],
                    File['/etc/statsd/config.js'],
                    Vcsrepo['/opt/statsd']],
  }

  # remove any stats that haven't been updated for ~9 months and
  # remove empty dirs
  cron { 'remove_old_stats':
    user        => 'root',
    hour        => '2',
    minute      => '0',
    command     => 'find /var/lib/graphite/storage/whisper -type f -mtime +270 -name \*.wsp -delete; find /var/lib/graphite/storage/whisper -depth -type d -empty -delete > /dev/null',
    environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
  }

}

