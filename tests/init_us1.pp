class { 'vidyo':
  ensure                => installed,
  endpointurl           => "http://${hostname}:8000",
  vidyoserver           => 'inin.sandboxga.vidyo.com',
  vidyoadmin            => 'admin',
  vidyopassword         => '&amp;TQdh1@mVuXFop0A7H',
  replayserver          => 'inin.sandboxgareplay.vidyo.com',
  replayadmin           => 'admin',
  replaypassword        => '&amp;TQdh1@mVuXFop0A7H',
  webbaseurl            => "http://${hostname}/vidyoweb",
  roomgroup             => 'VidyoIntegrationGroup',
  roomowner             => 'admin',
  extensionprefix       => '789',
  cicserver             => "${hostname}",
  usewindowsauth        => false,
  cicusername           => 'vagrant',
  cicpassword           => '1234',
  enablescreenrecording => true,
  addininstall          => true,
}
