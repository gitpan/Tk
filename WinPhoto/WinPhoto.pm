package Tk::WinPhoto;
require DynaLoader;
require Tk;
require Tk::Image;
require Tk::Photo;

use vars qw($VERSION);
$VERSION = '3.002'; # $Id: //depot/Tk8/WinPhoto/WinPhoto.pm#2$

use base  qw(DynaLoader);

bootstrap Tk::WinPhoto $Tk::VERSION;

1;

__END__

=head1 NAME

Tk::WinPhoto - Load a Photo image from a window

=for category Experimental Modules

=head1 SYNOPSIS

  use Tk;
  use Tk::WinPhoto;

  my $image = $widget->Photo('-format' => 'Window', -string => $widget);
  

=head1 DESCRIPTION

This is an extension for Tk800.* which will load a Photo image
from a snapshot of an X window.

=head1 AUTHOR

Nick Ing-Simmons E<lt>nick@ni-s.u-net.comE<gt>

=cut
