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
# [*addininstall*]
#   Specify whether the Vidyo addin should be installed locally. Default: false
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
#    addininstall          => false,
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
    $addininstall = false,
)
{

  $vidyoserviceinstallerdownloadurl                = 'https://onedrive.live.com/download?resid=181212A4EB2683F0!5963&authkey=!AON7UCxL06q40Mk&ithint=file%2cmsi'
  $setrecordingattributeshandlerdownloadurl        = 'https://onedrive.live.com/download?resid=181212A4EB2683F0!5976&authkey=!AAt-9yqo7AwWxU0&ithint=file%2ci3pub'
  $customgenericobjectdisconnecthandlerdownloadurl = 'https://onedrive.live.com/download?resid=181212A4EB2683F0!5977&authkey=!AAMdH_SfAFNIwug&ithint=file%2ci3pub'
  $clientaddininstallerdownloadurl                 = 'https://onedrive.live.com/download?resid=181212A4EB2683F0!5960&authkey=!AFFKpxg-HSAx4Jo&ithint=file%2cmsi'
  $vidyowebsitedownloadurl                         = 'https://onedrive.live.com/download?resid=181212A4EB2683F0!5964&authkey=!AMS4ku2lPI487-s&ithint=file%2czip'
  $ininwebsitedownloadurl                          = 'https://onedrive.live.com/download?resid=181212A4EB2683F0!5968&authkey=!ACakNrqbSG0IF7U&ithint=file%2czip'
  $customstoredproceduredownloadurl                = 'https://onedrive.live.com/download?resid=181212A4EB2683F0!5967&authkey=!ALUAsX1Jb9SHjqg&ithint=file%2csql'
  $sqlpowershelltoolsdownloadurl                   = 'https://download.microsoft.com/download/1/3/0/13089488-91FC-4E22-AD68-5BE58BD5C014/ENU/x86/PowerShellTools.msi'

  if ($::operatingsystem != 'Windows')
  {
    err('This module works on Windows only!')
    fail('Unsupported OS')
  } else {
    File { source_permissions => ignore } # Required for windows
  }

  $cache_dir = hiera('core::cache_dir', 'c:/users/vagrant/appdata/local/temp') # If I use c:/windows/temp then a circular dependency occurs when used with SQL
  if (!defined(File[$cache_dir]))
  {
    file {$cache_dir:
      ensure   => directory,
      provider => windows,
    }
  }

  $lognumber = '9999' # Report log to activate on CIC for custom handler
  $addinfinallocation = 'C:/I3/IC/Utilities/' # Where the addin msi is copied to

  # Install firefox
  package {'firefox':
    ensure   => present,
    provider => chocolatey,
    #onlyif   => "if ((Get-ItemProperty (\"hklm:\\software\\Wow6432Node\\mozilla.org\\Mozilla\") -name CurrentVersion | Select -exp CurrentVersion) -gt 42) {exit 1}", # Don't run if firefox v42 or greater has already been installed
  }

  ###################################
  # Integration Server Installation #
  ###################################

  # Copy MSIs from Dropbox
  exec {'Download Service Installer':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('${vidyoserviceinstallerdownloadurl}','${cache_dir}/vidyoserviceinstaller.msi')",
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

  ####################################
  # Integration Server Configuration #
  ####################################

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

  file_line {'Configure Has Replay Server':
    path     => 'C:/Program Files (x86)/Interactive Intelligence/Vidyo Integration Service/VidyoIntegrationWindowsService.exe.config',
    line     => "<add key=\"HasReplayServer\" value=\"${hasreplayserver}\"/>",
    match    => '.*HasReplayServer.*',
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

  ###################
  # Custom Handlers #
  ###################

  # Enable CIC log 9999
  exec {'Enable Log 9999':
    command  => template('vidyo/enablelog.ps1.erb'),
    provider => powershell,
  }

  exec {'Download Vidyo_SetRecordingAttributes.i3pub':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('${setrecordingattributeshandlerdownloadurl}','${cache_dir}/Vidyo_SetRecordingAttributes.i3pub')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  exec {'Download CustomGenericObjectDisconnect.i3pub':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('${customgenericobjectdisconnecthandlerdownloadurl}','${cache_dir}/CustomGenericObjectDisconnect.i3pub')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  exec {'Publish Vidyo_SetRecordingAttributes':
    command  => "EicPublisherU /noprompts ${cache_dir}/Vidyo_SetRecordingAttributes.i3pub",
    path     => $::path,
    cwd      => $::system32,
    provider => powershell,
    require  => [
      Package['vidyoserviceinstaller'],
      Exec['Download Vidyo_SetRecordingAttributes.i3pub'],
    ],
  }

  exec {'Publish CustomGenericObjectDisconnect':
    command  => "EicPublisherU /noprompts ${cache_dir}/CustomGenericObjectDisconnect.i3pub",
    path     => $::path,
    cwd      => $::system32,
    provider => powershell,
    require  => [
      Exec['Download CustomGenericObjectDisconnect.i3pub'],
      Exec['Publish Vidyo_SetRecordingAttributes'],
    ],
  }

  ######################
  # Vidyo Client Addin #
  ######################

  # Download and copy VidyoAddinInstaller to install folder
  exec {'Download Client add-in':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('${clientaddininstallerdownloadurl}','${cache_dir}/vidyoaddininstaller.msi')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  file {"${addinfinallocation}/VidyoAddinInstaller.msi":
    ensure  => present,
    source  => "${cache_dir}/vidyoaddininstaller.msi",
    require => Exec['Download Client add-in'],
  }

  # Install addin
  if ($addininstall) {
    package {'Install Vidyo Addin':
      ensure => installed,
      source => "${addinfinallocation}/vidyoaddininstaller.msi",
      install_options => [
        '/l*v',
        'C:\\windows\\logs\\addininstall.log',
        { 'INSTALLLOCATION' => 'C:\\I3\\IC\\SERVER\\Addins'},
      ],
      require => File["${addinfinallocation}/VidyoAddinInstaller.msi"],
    }
  }

  #################
  # VidyoWeb Site #
  #################

  # Download and copy sample web site to C:\inetpub\wwwroot\vidyoweb
  exec {'Download vidyoweb web site':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('${vidyowebsitedownloadurl}','${cache_dir}/vidyoweb.zip')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  unzip {"${cache_dir}/vidyoweb.zip":
    destination => 'C:/inetpub/wwwroot/vidyoweb',
    creates     => 'C:/inetpub/wwwroot/vidyoweb/index.html',
    require     => Exec['Download vidyoweb web site'],
  }

  # Give Write privileges to IUSR account. Permissions are inherited downstream to subfolders.
  acl {'C:/inetpub/wwwroot':
    permissions => [
      {identity => 'IIS_IUSRS', rights => ['read']},
      {identity => 'IUSR',      rights => ['write']},
    ],
    require     => Unzip["${cache_dir}/vidyoweb.zip"],
  }

  # Create vidyo workgroup?
  # TODO Add parameter to specify workgroup(s) used

  #################
  # ININ Web Site #
  #################

  # Download and copy generic (inin) customer web site to C:\inetpub\wwwroot\inin
  exec {'Download inin web site':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('${ininwebsitedownloadurl}','${cache_dir}/ininweb.zip')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  unzip {"${cache_dir}/ininweb.zip":
    destination => 'C:/inetpub/wwwroot/inin',
    creates     => 'C:/inetpub/wwwroot/inin/index.html',
    require     => Exec['Download inin web site'],
  }

  # Configure ininvid_serverRoot in index.html, acdwait.html, injector.js
  file_line {'Configure ininvid_serverRoot in index.html':
    path     => 'C:/inetpub/wwwroot/inin/index.html',
    line     => "var ininvid_serverRoot = 'http://${hostname}:8000';",
    match    => '.*var ininvid_serverRoot.*',
    multiple => false,
    require  => Unzip["${cache_dir}/ininweb.zip"],
  }

  file_line {'Configure ininvid_serverRoot in acdwait.html':
    path     => 'C:/inetpub/wwwroot/inin/acdwait.html',
    line     => "var ininvid_serverRoot = 'http://${hostname}:8000';",
    match    => '.*var ininvid_serverRoot.*',
    multiple => false,
    require  => Unzip["${cache_dir}/ininweb.zip"],
  }

  file_line {'Configure ininvid_serverRoot in injector.js':
    path     => 'C:/inetpub/wwwroot/inin/ininvid/injector.js',
    line     => "var ininvid_serverRoot = 'http://${hostname}:8000';",
    match    => '.*var ininvid_serverRoot.*',
    multiple => false,
    require  => Unzip["${cache_dir}/ininweb.zip"],
  }

  # Add shortcut to desktop. Should probably move this to a template.
  file {'Add Desktop Shortcut Script':
    ensure  => present,
    path    => "${cache_dir}\\createininshortcut.ps1",
    content => "
      function CreateShortcut(\$AppLocation, \$description){
        \$WshShell = New-Object -ComObject WScript.Shell
        \$Shortcut = \$WshShell.CreateShortcut(\"\$env:USERPROFILE\\Desktop\\\$description.url\")
        \$Shortcut.TargetPath = \$AppLocation
        #\$Shortcut.Description = \$description
        \$Shortcut.Save()
      }
      CreateShortcut \"http://${hostname}/inin\" \"Vidyo ININ\"
      ",
  }

  # Add .pkg to Mime Types on IIS (otherwise MacOS X app cannot be downloaded)
  exec{'Configure pkg Mime Type':
    command => "cmd.exe /c \"%windir%\\system32\\inetsrv\\appcmd set config \"Default Web Site/vidyoweb\" -section:staticContent /+\"[fileExtension='.pkg',mimeType='application/octet-stream']\"",
    path    => $::path,
    cwd     => $::system32,
    unless  => "cmd.exe /c \"%windir%\\system32\\inetsrv\\appcmd list config \"Default Web Site/vidyoweb\" -section:staticContent | findstr /l .pkg\"",
  }

  # Add shortcut to fake ININ web site on desktop
  exec {'Add ININ Web Desktop Shortcut':
    command  => "${cache_dir}\\createininshortcut.ps1",
    provider => powershell,
    timeout  => 1800,
    require  => [
      File['Add Desktop Shortcut Script'],
      Service['Start Integration Server Service'],
    ],
  }

  ########################
  # SQL Stored Procedure #
  ########################

  exec {'Download Custom Stored Procedure':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('${customstoredproceduredownloadurl}','${cache_dir}/vidyo_set_custom_attribute.sql')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  exec {'Download SQL Powershell Tools':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('${sqlpowershelltoolsdownloadurl}','${cache_dir}/PowerShellTools.msi')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  package {'Install SQL Powershell Tools':
    ensure          => installed,
    source          => "${cache_dir}/PowerShellTools.msi",
    install_options => [
      '/l*v',
      'C:\\windows\\logs\\powershelltools.log',
    ],
    require         => Exec['Download SQL Powershell Tools'],
  }

  exec {'Add Custom Stored Procedure':
    command  => template('vidyo/addstoredprocedure.ps1.erb'),
    provider => powershell,
    require  => [
      Exec['Download Custom Stored Procedure'],
      Package['Install SQL Powershell Tools'],
    ],
  }

  #################
  # Start service #
  #################

  # Add Interaction Center dependency (CIC needs to start before the integration server)
  exec {'Add Interaction Center Dependency':
    command  => "sc config VidyoIntegrationService depend= \"Interaction Center\"",
    path     => $::path,
    cwd      => $::system32,
    require => [
      File_Line['Configure User Service Endpoint'],
      File_Line['Configure Admin Service Endpoint'],
      File_Line['Configure Guest Service Endpoint'],
      File_Line['Configure CIC Server'],
      File_Line['Configure Service Endpoint URL'],
      File_Line['Configure Web Base Url'],
      File_Line['Configure Room Group'],
      File_Line['Configure Room Owner'],
      File_Line['Configure Admin Username'],
      File_Line['Configure Admin Password'],
      File_Line['Configure Service Endpoint Uri'],
      File_Line['Configure Extension Prefix'],
      File_Line['Configure Has Replay Server'],
      Exec['Add Custom Stored Procedure'],
      Exec['Publish Vidyo_SetRecordingAttributes'],
      Exec['Publish CustomGenericObjectDisconnect'],
    ],
  }

  # Finally, we can start the service
  service {'Start Integration Server Service':
    ensure  => running,
    enable  => true,
    name    => 'VidyoIntegrationService',
    require => Exec['Add Interaction Center Dependency'],
  }

}
