# == Class: vidyo
#
# Installs and configures ININ's Vidyo integration server
#
# Requirements:
#   CIC Server 2015R4+
#   .Net 4.5.1
#   Interaction Desktop
#
# === Parameters
#
# Document parameters here.
#
# [*ensure*]
#   only installed is supported at this time
#
# [*endpointurl*]
#   Specify the integration server endpoint url (i.e. http://server:8000). Default: http://<current machine name>:8000
#
# [*vidyoserver*]
#   Specify the name or IP address of the vidyo portal server
#
# [*vidyoadmin*]
#   Specify the Vidyo admin username. Default: admin
#
# [*vidyopassword*]
#   Specify the password for the vidyo admin
#
# [*replayserver*]
#   Specify (if it exists) the vidyo replay server name
#
# [*replayadmin*]
#   Specify the replay admin username. Default: admin
#
# [*replaypassword*]
#   Specify the password for the replay admin username
#
# [*webbaseurl*]
#   Specify the base url to access the web page that initiates the video conversation (i.e. http://IIS/vidyoweb). Default value: http://<current machine name>/vidyoweb (if IIS is installed on the local machine)
#
# [*roomgroup*]
#   Specify the name of the Vidyo room group to use when creating rooms. This is purely for identification purposes, but the group must exist on the Vidyo server or the integration will be unable to create rooms. Default value: VidyoIntegrationGroup
#
# [*roomowner*]
#   Specify the default account to use as the room owner when creating rooms. This can be any account. This is typically configured to be the same as the Vidyo integration admin user. Default value: same as vidyoadmin
#
# [*extensionprefix*]
#   Specify the default extension prefix.
#
# [*cicserver*]
#   Specify the IP or server name of your CIC server. Default: localhost
#
# [*usewindowsauth*]
#   Specify whether windows authentication should be used to connect to CIC. If this is set to true, Windows authentication will be used and cicusername and cicpassword values will be ignored. Default: false
#
# [*cicusername*]
#   Specify the CIC username to use for this integration. Default: vagrant
#
# [*cicpassword*]
#   Specify the CIC user password. Default: 1234
#
# [*enablescreenrecording*]
#   Specify whether screen recordings should be initiated when an agent picks up the generic object. This is used to then have IR store data about the Vidyo conversation. Default: false
#
# === Examples
#
#  class { 'vidyo':
#    ensure                => installed,
#    endpointurl           => 'http://integrationserver:8000',
#    vidyoserver           => 'vidyoportal',
#    vidyoadmin            => 'admin',
#    vidyopassword         => 'password',
#    replayserver          => 'vidyoreplay',
#    replayadmin           => 'admin',
#    replaypassword        => 'password',
#    webbaseurl            => 'http://iis/vidyoweb',
#    roomgroup             => 'VidyoIntegrationGroup',
#    roomowner             => 'admin',
#    extensionprefix       => '789',
#    cicserver             => 'localhost',
#    usewindowsauth        => false,
#    cicusername           => 'cicadmin',
#    cicpassword           => '1234',
#    enablescreenrecording => true,
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
    $endpointurl = "http://${hostname}:8000",
    $vidyoserver,
    $vidyoadmin = 'admin',
    $vidyopassword,
    $replayserver,
    $replayadmin = 'admin',
    $replaypassword,
    $webbaseurl = "http://${hostname}/vidyoweb",
    $roomgroup = 'VidyoIntegrationGroup',
    $roomowner = $vidyoadmin,
    $extensionprefix,
    $cicserver = 'localhost',
    $usewindowsauth = false,
    $cicusername = 'vagrant',
    $cicpassword = '1234',
    $enablescreenrecording = false,
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

  # Configure VidyoIntegrationWindowsService.exe.config
  file_line {'Configure User Service Endpoint':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<endpoint address=\"http://${vidyoserver}/services/v1_1/VidyoPortalUserService/\"",
    match    => '.*VIDYOAPISERVER.*VidyoPortalUserService.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  file_line {'Configure Admin Service Endpoint':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<endpoint address=\"http://${vidyoserver}/services/v1_1/VidyoPortalAdminService/\"",
    match    => '.*VIDYOAPISERVER.*VidyoPortalAdminService.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  file_line {'Configure Guest Service Endpoint':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<endpoint address=\"http://${vidyoserver}/services/v1_1/VidyoPortalGuestService/\"",
    match    => '.*VIDYOAPISERVER.*VidyoPortalGuestService.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  if ($replayserver) {
    file_line {'Configure Replay Service Endpoint':
      path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
      line     => "<endpoint address=\"http://${replayserver}/replay/services/VidyoReplayContentManagementService/\"",
      match    => '.*VIDYOREPLAYSERVER.*VidyoReplayContentManagementService.*',
      multiple => false,
      require  => Package['vidyoserviceinstaller'],
    }
  }

  file_line {'Configure CIC Server':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<add key=\"CicServer\" value=\"${cicserver}\"/>",
    match    => '.*CicServer.*CICSERVER.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  if ($usewindowsauth) {
    file_line {'Enable CIC Use Windows Auth':
      path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
      line     => "<add key=\"CicUseWindowsAuth\" value=\"true\"/>",
      match    => '.*CicUseWindowsAuth.*',
      multiple => false,
      require  => Package['vidyoserviceinstaller'],
    }
  } else {
    file_line {'Disable CIC Use Windows Auth':
      path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
      line     => "<add key=\"CicUseWindowsAuth\" value=\"false\"/>",
      match    => '.*CicUseWindowsAuth.*',
      multiple => false,
      require  => Package['vidyoserviceinstaller'],
    }

    file_line {'Configure CIC User':
      path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
      line     => "<add key=\"CicUsername\" value=\"${cicusername}\"/>",
      match    => '.*CicUsername.*',
      multiple => false,
      require  => Package['vidyoserviceinstaller'],
    }

    file_line {'Configure CIC Password':
      path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
      line     => "<add key=\"CicPassword\" value=\"${cicpassword}\"/>",
      match    => '.*CicPassword.*',
      multiple => false,
      require  => Package['vidyoserviceinstaller'],
    }
  }

  file_line {'Configure Service Endpoint URL':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<add key=\"CicServiceEndpointUri\" value=\"${endpointurl}\"/>",
    match    => '.*CicServiceEndpointUri.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  file_line {'Configure Web Base Url':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<add key=\"VidyoWebBaseUrl\" value=\"${webbaseurl}\"/>",
    match    => '.*VidyoWebBaseUrl.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  file_line {'Configure Room Group':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<add key=\"VidyoRoomGroup\" value=\"${roomgroup}\"/>",
    match    => '.*VidyoRoomGroup.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  file_line {'Configure Room Owner':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<add key=\"VidyoRoomOwner\" value=\"${roomowner}\"/>",
    match    => '.*VidyoRoomOwner.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  file_line {'Configure Admin Username':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<add key=\"VidyoAdminUsername\" value=\"${vidyoadmin}\"/>",
    match    => '.*VidyoAdminUsername.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  file_line {'Configure Admin Password':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<add key=\"VidyoAdminPassword\" value=\"${vidyopassword}\"/>",
    match    => '.*VidyoAdminPassword.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  file_line {'Configure Service Endpoint Uri':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<add key=\"VidyoServiceEndpointUri\" value=\"${endpointurl}\"/>",
    match    => '.*VidyoServiceEndpointUri.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  file_line {'Configure Extension Prefix':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<add key=\"VidyoExtensionPrefix\" value=\"${extensionprefix}\"/>",
    match    => '.*VidyoExtensionPrefix.*',
    multiple => false,
    require  => Package['vidyoserviceinstaller'],
  }

  if ($enablescreenrecording == true) {
    file_line {'Configure Screen Recording':
      path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
      line     => "<add key=\"EnableScreenRecording\" value=\"1\"/>",
      match    => '.*EnableScreenRecording.*',
      multiple => false,
      require  => Package['vidyoserviceinstaller'],
    }
  }

  # Enable CIC log 9999
  # Publish custom handlers

  # Download and copy VidyoAddinInstaller to install folder
  exec {'Download Client add-in':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('https://www.dropbox.com/s/nemyncojolnl6sz/VidyoAddinInstaller_1.1.1.0.msi?dl=1','${cache_dir}/vidyoaddininstaller.msi')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  # Create test workgroups?
  # Download and copy test web site to C:\inetpub\wwwroot\vidyoweb
    # Configure ininvid_serverRoot
    # Configure workgroups
  # Add custom stored procedure to SQL
  # Add favorites to Firefox?

}
