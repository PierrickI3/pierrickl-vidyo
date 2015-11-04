# == Class: vidyo
#
# Installs and configures ININ's Vidyo integration server
#
# === Parameters
#
# Document parameters here.
#
# [*ensure*]
#   only installed is supported at this time
#
# [*router*]
#   Specify the vidyo router name
#
# [*routeradmin*]
#   Specify the router admin username
#
# [*routerpassword*]
#   Specify the password for the router admin username
#
# [*replayserver*]
#   Specify (if it exists) the vidyo replay server name
#
# [*replayadmin*]
#   Specify the replay admin username
#
# [*replaypassword*]
#   Specify the password for the replay admin username
#
# === Examples
#
#  class { 'vidyo':
#    ensure         => installed,
#    router         => vidyorouter,
#    routeradmin    => 'admin',
#    routerpassword => 'password',
#    replayserver   => vidyoreplay,
#    replayadmin    => 'admin',
#    replaypassword => 'password',
#  }
#
# === Authors
#
# Pierrick Lozach <pierrick.lozach@inin.com>
#
# === Copyright
#
# Copyright 2015 Interactive Intelligence, Inc.
#
class vidyo (
    $ensure = installed,
    $router = 'vidyorouter',
    $routeradmin = 'admin',
    $routerpassword,
    $replayserver = 'vidyoreplay',
    $replayadmin = 'admin',
    $replaypassword,
)
{

  if ($::operatingsystem != 'Windows')
  {
    err('This module works on Windows only!')
    fail('Unsupported OS')
  }

  $cache_dir = hiera('core::cache_dir', 'c:/users/vagrant/appdata/local/temp') # If I use c:/windows/temp then a circular dependency occurs when used with SQL
  if (!defined(File[$cache_dir]))
  {
    file {$cache_dir:
      ensure   => directory,
      provider => windows,
    }
  }

  # Install firefox
  package {'firefox':
    ensure   => present,
    provider => chocolatey,
    #onlyif   => "if ((Get-ItemProperty (\"hklm:\\software\\Wow6432Node\\mozilla.org\\Mozilla\") -name CurrentVersion | Select -exp CurrentVersion) -gt 42) {exit 1}", # Don't run if firefox v42 or greater has already been installed
  }

  # Copy MSIs from Dropbox
  exec {'Download Service Installer':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('https://www.dropbox.com/s/b7j1kawd51wycs2/VidyoIntegrationServiceInstaller_1.1.1.0.msi?dl=1','${cache_dir}/vidyoserviceinstaller.msi')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  # Install vidyo integration server
  package {'vidyoserviceinstaller':
    ensure => installed,
    source => "${cache_dir}/vidyoserviceinstaller.msi",
    install_options => [
      '/l*v',
      'C:\\windows\\logs\\serviceinstall.log',
    ],
    require => Exec['Download Service Installer'],
  }

  # Configure app.config
  # Enable CIC log 9999
  # Publish custom handlers

  # Download and copy VidyoAddinInstaller to install folder
  pget {'Download Client add-in':
    source         => 'https://www.dropbox.com/s/nemyncojolnl6sz/VidyoAddinInstaller_1.1.1.0.msi?dl=1',
    target         => $cache_dir,
    targetfilename => 'vidyoaddininstaller.msi',
    overwrite      => true,
  }

  # Create test workgroups?
  # Download and copy test web site to C:\inetpub\wwwroot\vidyoweb
    # Configure ininvid_serverRoot
    # Configure workgroups
  # Add custom stored procedure to SQL
  # Add favorites to Firefox?

}
