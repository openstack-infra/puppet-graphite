# == Class: graphite
#
class graphite(
  $vhost_name = $::fqdn,
  $graphite_admin_user = '',
  $graphite_admin_email = '',
  $graphite_admin_password = '',
  $manage_pip = '',
) {
  $packages = [ 'python-django',
                'python-django-tagging',
                'python-cairo',
                'nodejs' ]

  include apache

  if $manage_pip == true {
    package {'pip':
      ensure => latest
    }
  }

  package { $packages:
    ensure => present,
  }

  vcsrepo { '/opt/graphite-web':
    ensure   => present,
    provider => git,
    # revision => '0.9.x',
    # pin version because of https://github.com/graphite-project/graphite-web/issues/650
    revision => '7f8c33da809e2938df55c1ff57ab5329d8d7b878',
    source   => 'https://github.com/graphite-project/graphite-web.git',
  }

  exec { 'install_graphite_web' :
    command     => 'pip install --install-option="--install-scripts=/usr/local/bin" --install-option="--install-lib=/usr/local/lib/python2.7/dist-packages" --install-option="--install-data=/var/lib/graphite" /opt/graphite-web',
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

  exec { 'install_carbon' :
    command     => 'pip install --install-option="--install-scripts=/usr/local/bin" --install-option="--install-lib=/usr/local/lib/python2.7/dist-packages" --install-option="--install-data=/var/lib/graphite" /opt/carbon',
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

  file { '/var/lib/graphite/storage':
    ensure  => directory,
    owner   => 'www-data',
    group   => 'www-data',
    require => [Package[$::apache::params::apache_name],
                File['/var/lib/graphite']]
  }

  file { '/var/log/graphite':
    ensure  => directory,
    owner   => 'www-data',
    group   => 'www-data',
    require => Package[$::apache::params::apache_name],
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
      Package[$::apache::params::apache_name],
      File['/usr/local/lib/python2.7/dist-packages/graphite/local_settings.py'],
      File['/usr/local/bin/graphite-init-db.py'],
      File['/etc/graphite/admin.ini']],
  }

  apache::vhost { $vhost_name:
    port     => 80,
    priority => '50',
    docroot  => '/var/lib/graphite/webapp',
    template => 'graphite/graphite.vhost.erb',
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
    mode    => '0555',
    source  => 'puppet:///modules/graphite/graphite-init-db.py'
  }

  file { '/etc/graphite/admin.ini':
    mode    => '0400',
    owner   => 'www-data',
    group   => 'www-data',
    content => template('graphite/admin.ini'),
    require => [ File['/etc/graphite'],
      Package[$::apache::params::apache_name]],
  }

  file { '/etc/init.d/carbon-cache':
    mode    => '0555',
    source  => 'puppet:///modules/graphite/carbon-cache.init'
  }

  file { '/etc/init.d/statsd':
    mode    => '0555',
    source  => 'puppet:///modules/graphite/statsd.init'
  }

  file { '/etc/default/statsd':
    mode    => '0444',
    source  => 'puppet:///modules/graphite/statsd.default'
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

