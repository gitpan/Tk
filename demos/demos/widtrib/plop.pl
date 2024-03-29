# Plot a series of continuous functions on a Perl/Tk Canvas.
#
# This program is described in the Perl/Tk column from Volume 1, Issue 1 of
# The Perl Journal (http://tpj.com/tpj), and is included in the Perl/Tk
# distribution with permission.  It has been modified slightly to conform
# to the widget demo standard.

use English;
use WidgetDemo;
use vars qw($TOP @FUNCTIONS @COLORS $NUM_COLORS $X_MIN $X_MAX $Y_MIN $Y_MAX
	    $DX $DY $MIN_PXL $MAX_PXL $MARGIN $ALEN $ORIGINAL_CURSOR $CANV
	    $DIALOG_ABOUT $DIALOG_USAGE $MBF $TEXT %ERRORS);

sub plop {
    my($demo) = @ARG;
    my $demo_widget = $MW->WidgetDemo(-name => $demo,
				      -text => 'This demonstration allows you to enter arithmetic functions in the text widow and plot them.  The X and Y axes limits can be changed to scale the plotting canvas.',
				      -geometry_manager => 'pack');
    $TOP = $demo_widget->top;

#!/usr/local/bin/perl -w
#
# plot_program - plot a series of continuous functions on a Perl/Tk Canvas.
#
# Stephen O. Lidie, Lehigh University Computing Center, lusol@Lehigh.EDU
# 96/01/27.
#
# Copyright (C) 1996 - 1996 Stephen O. Lidie. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself.

require 5.002;
use English;
use strict;
use Tk;
require Tk::Dialog;
require Tk::LabEntry;
eval {require "plop.fnc";};	# user supplied math functions

# Predeclare global subroutines and variables.

sub collect_errors;
sub display_coordinates;
sub initialize_canvas;
sub initialize_dialogs;
sub initialize_functions;
sub initialize_menus;
sub make_menubutton;
sub plot_functions;
sub update_functions;

my $VERSION = '1.0';

# The default sample functions and limits, each in a different color.

@FUNCTIONS = ('sin($x)', 'cos($x)', 'exp($x)', '$x', 'int($x)');
@COLORS = qw(red green blue orange olivedrab cyan black salmon purple);
$NUM_COLORS = scalar @COLORS;
($X_MIN, $X_MAX, $Y_MIN, $Y_MAX) = (-10, 10, -10, 10);
($DX, $DY) = ($X_MAX - $X_MIN, $Y_MAX - $Y_MIN);

# Declare constants that configure the plotting area: a square approximately
# 500 pixels on a side, with left/right and top/bottom margins of 80 pixles
# where we can paint axes labels.  With this layout there is a 340x340 area
# available for graphs.

$MIN_PXL = 0;		        # minimum Canvas pixel coordinate
$MAX_PXL = 400;		        # maximum Canvas pixel coordinate
$MARGIN = 80;		        # margin size, in pixels
$ALEN = $MAX_PXL - 2 * $MARGIN;	# X/Y axes length, in pixels

# Declare Perl/Tk widgets and other data.

#my $CANV;			# Canvas widget used for plotting functions
#my $DIALOG_ABOUT;		# Dialog widget showing "About" information
#my $DIALOG_USAGE;		# Dialog widget describing plot usage
#my $MBF;			# Menubutton frame
$ORIGINAL_CURSOR = ($TOP->configure(-cursor))[3]; # restore this cursor
#my $TEXT;			# Text widget showing function definitions

# %ERRORS is a hash to collect eval() and -w errors.  The keys are the error
# messages themselves and the values are the number of times a particular
# error was detected.

#my %ERRORS;

# Begin main.

initialize_dialogs;
initialize_menus;
initialize_canvas;
initialize_functions;

# End main.

sub collect_errors {

    # Update the hash %ERRORS with the latest eval() error message.  Remove
    # the eval() line number (it's useless to us) to maintain a compact hash.
    
    my($error) = @ARG;

    $error =~ s/eval\s+(\d+)/eval/;
    $ERRORS{$error}++;

} # end collect_errors

sub display_coordinates {

    # Print Canvas and Plot coordinates.

    my($canvas) = @ARG;

    my $e = $canvas->XEvent;
    my($canv_x, $canv_y) = ($e->x, $e->y); 
    my($x, $y);
    $x = $X_MIN + $DX * (($canv_x - $MARGIN) / $ALEN);
    $y = $Y_MAX - $DY * (($canv_y - $MARGIN) / $ALEN);
    print STDOUT "\nCanvas x = $canv_x, Canvas y = $canv_y.\n";
    print STDOUT  "Plot x = $x, Plot y = $y.\n";

} # end display_coordinates

sub initialize_canvas {

    # Create the Canvas widget and draw axes and labels.

    my($label_offset, $tick_length) = (20, 5);

    $CANV = $TOP->Canvas(
			-width  => $MAX_PXL + $MARGIN * 2, 
			-height => $MAX_PXL, 
			-relief => 'sunken',
			);
    $CANV->pack;
    $CANV->Tk::bind('<Button-1>' => \&display_coordinates);

    $CANV->create('text', 
		  325, 25, 
		  -text => 'Plot Continuous Functions Of The Form y=f($x)',
		  -fill => 'blue',
		  );

    # Create the line to represent the X axis and label it.  Then label the
    # minimum and maximum X values and draw tick marks to indicate where they
    # fall.  The axis limits are LabEntry widgets embedded in Canvas windows.

    $CANV->create('line',
		  $MIN_PXL + $MARGIN, $MAX_PXL - $MARGIN, 
		  $MAX_PXL - $MARGIN, $MAX_PXL - $MARGIN,
		  );

    $CANV->create('window',
		  $MIN_PXL + $MARGIN, $MAX_PXL - $label_offset,
		  -window => $TOP->LabEntry(
					   -textvariable => \$X_MIN,
					   -label => 'X Minimum',
					   ),
		  );
    $CANV->create('line', 
		  $MIN_PXL + $MARGIN, $MAX_PXL - $MARGIN - $tick_length,
		  $MIN_PXL + $MARGIN, $MAX_PXL - $MARGIN + $tick_length,
		  );

    $CANV->create('window', 
		  $MAX_PXL - $MARGIN, $MAX_PXL - $label_offset,
		  -window => $TOP->LabEntry(
					   -textvariable => \$X_MAX,
					   -label => 'X Maximum',
					   ),
		  );
    $CANV->create('line', 
		  $MAX_PXL - $MARGIN, $MAX_PXL - $MARGIN - $tick_length,
		  $MAX_PXL - $MARGIN, $MAX_PXL - $MARGIN + $tick_length,
		  );

    # Create the line to represent the Y axis and label it.  Then label the 
    # minimum and maximum Y values and draw tick marks to indicate where they
    # fall.  The axis limits are LabEntry widgets embedded in Canvas windows.

    $CANV->create('line', 
		  $MAX_PXL - $MARGIN, $MIN_PXL + $MARGIN, 
		  $MAX_PXL - $MARGIN, $MAX_PXL - $MARGIN,
		  );

    $CANV->create('window', 
		  $MAX_PXL + $label_offset, $MIN_PXL + $MARGIN,
		  -window => $TOP->LabEntry(
					   -textvariable => \$Y_MAX,
					   -label => 'Y Maximum',
					   ),
		  );
    $CANV->create('line', 
		  $MAX_PXL - $MARGIN - $tick_length, $MIN_PXL + $MARGIN,
		  $MAX_PXL - $MARGIN + $tick_length, $MIN_PXL + $MARGIN,
		  );

    $CANV->create('window', 
		  $MAX_PXL + $label_offset, $MAX_PXL - $MARGIN,
		  -window => $TOP->LabEntry(
					   -textvariable => \$Y_MIN,
					   -label => 'Y Minimum',
					   ),
		  );
    $CANV->create('line', 
		  $MAX_PXL - $MARGIN - $tick_length, $MAX_PXL - $MARGIN,
		  $MAX_PXL - $MARGIN + $tick_length, $MAX_PXL - $MARGIN,
		  );

} # end initialize_canvas

sub initialize_dialogs {

    # Create all application Dialog objects.

    $DIALOG_ABOUT = $TOP->Dialog(
				-title   => 'About',
				-text    => 
"plot_program $VERSION\n\n95/12/04\n\nThis program is described in the Perl/Tk column from Volume 1, Issue 1 of The Perl Journal (http://tpj.com/tpj), and is included in the Perl/Tk distribution with permission.",
				-bitmap  => 'info',
				-buttons => ['Dismiss'],
				);
    $DIALOG_ABOUT->configure(-wraplength => '6i');
    $DIALOG_USAGE = $TOP->Dialog(
				-title   => 'Usage',
				-buttons => ['Dismiss'],
				);
    $DIALOG_USAGE->Subwidget('message')->configure(
						   -wraplength => '4i',
						   -text       => "plot_program iterates over the range of values X Minimum to X Maximum, setting the variable \$x to each value in turn, then evaluates each f(\$x) and paints a point on the Y axis.  The X axis increment is (Xmax - Xmin) / $ALEN.\n\nJust enter your functions in the Text widget and click the Plot button.\n\nYou can define a file named \"plop.fnc\" that contains additional private math functions, which is automatically \"require\"d by plot_program.  In this file are your private functions that you can plot.\n\nPressing button one on the pointing device displays on standard output the current canvas and plot X and Y coordinates.",
						   );

} # end initialize_dialogs

sub initialize_functions {

    # Pack a spacer Frame and then display instructions in a Label widget.

    $TOP->Frame(-height => 20)->pack;
    $TOP->Label(
	       -text       => 'Enter your functions here',
	       -foreground => 'blue',
	       )->pack;

    # Create a Frame with a scrollable Text widget that displays the function
    # list, and a Button to initiate plot activities.

    my $functions_frame = $TOP->Frame;
    $functions_frame->pack;
    $TEXT = $functions_frame->Text(-height => 6);
    $TEXT->pack;
    $functions_frame->AddScrollbars($TEXT);
    $functions_frame->configure(-scrollbars => 'e');
    update_functions;

    my $buttons_frame = $TOP->Frame;
    $buttons_frame->pack(-padx => 10, -pady => 5, -expand => 1, -fill => 'x');
    my @pack_attributes = qw(-side left -fill x -expand 1);
    $buttons_frame->Button(
			   -text    => 'Plot', 
			   -command => \&plot_functions,
			   )->pack(@pack_attributes);

} # end initialize_functions

sub initialize_menus {

    # Create the Menubuttons and their associated Menu items.

    $MBF = $TOP->Frame(-relief => 'raised', -borderwidth => 1);
    $MBF->pack(-fill => 'x');
	
    make_menubutton($MBF, 'File', 0, 'left',
		    [
		     ['Quit',  [$TOP => 'bell'],          0],
		    ],
		   );
    make_menubutton($MBF, 'Help', 0, 'right',
		    [
		     ['About', [$DIALOG_ABOUT => 'Show'], 0],
		     ['',      undef,                     0],
		     ['Usage', [$DIALOG_USAGE => 'Show'], 0],
		    ],
		   );

} # end initialize_menus

sub make_menubutton {
	
    # Make a Menubutton widget; note that the Menu is automatically created.  
    # If the label is '', make a separator.

    my($mbf, $mb_label, $mb_label_underline, $pack, $mb_list_ref) = @ARG;

    my $mb = $mbf->Menubutton(
			       -text      => $mb_label, 
			       -underline => $mb_label_underline,
			      );
    my $mb_list;
    foreach $mb_list (@{$mb_list_ref}) {
	$mb_list->[0] eq '' ? $mb->separator :
	    $mb->command(
			 -label     => $mb_list->[0], 
			 -command   => $mb_list->[1], 
			 -underline => $mb_list->[2],
			 );
    }
    $mb->pack(-side => $pack);

} # end make_menubutton

sub plot_functions {

    # Plot all the functions.

    my($x, $y, $canv_x, $canv_y) = (0, 0, 0, 0);
    $canv_x = $MIN_PXL + $MARGIN; # X minimum
    $TOP->configure(-cursor => 'watch');
    $DX = $X_MAX - $X_MIN;	# update delta X
    $DY = $Y_MAX - $Y_MIN;	# update delta Y
    $CANV->delete('plot');	# erase all previous plots
    
    # Fetch the newline-separated Text widget contents and update the function
    # list @FUNCTIONS.  Also update the Text widget with the new colors.

    @FUNCTIONS = ();
    foreach (split /\n/, $TEXT->get('0.0', 'end')) {
	next if $ARG eq '';
	push @FUNCTIONS, $ARG;
    }
    update_functions;
    $TOP->idletasks;

    %ERRORS = ();
    $SIG{'__WARN__'} = sub {collect_errors($ARG[0])};

ALL_X_VALUES:
    for ($x = $X_MIN; $x <= $X_MAX; $x += ($X_MAX - $X_MIN) / $ALEN) {

      ALL_FUNCTIONS:
	foreach (0 .. $#FUNCTIONS) {
	    next if $FUNCTIONS[$ARG] =~ /^ERROR:/;
	    $y = eval $FUNCTIONS[$ARG];
	    if ($::EVAL_ERROR) {
		collect_errors($::EVAL_ERROR);
		next;
	    }
	    $canv_y = (($Y_MAX - $y) / $DY) * $ALEN + $MARGIN;
	    $CANV->create('text', $canv_x, $canv_y,
			  -fill => $COLORS[$ARG % $NUM_COLORS],
			  -tags => ['plot'],
			  -text => '.',
			  ) if $canv_y > $MIN_PXL + $MARGIN and 
			       $canv_y < $MAX_PXL - $MARGIN;
	} # forend ALL_FUNCTIONS

	$canv_x++;		# next X pixel

    } # forend ALL_X_VALUES

    $TOP->configure(-cursor => $ORIGINAL_CURSOR);
    $TOP->idletasks;

    # Print all the eval() errors to alert the user of malformed functions.

    print STDOUT "\n" if %ERRORS;
    foreach (keys %ERRORS) {
	print STDOUT "$ERRORS{$ARG} occurrences of $ARG";
    }

} # end plot_functions

sub update_functions {

    # Insert the function list into the Text widget.

    $TEXT->delete('0.0', 'end');
    my $i = 0;
    foreach (@FUNCTIONS) {
	$TEXT->insert('end', "$ARG\n", [$i]);
	$TEXT->tagConfigure($i,
		   -foreground => $COLORS[$i % $NUM_COLORS],
		   -font       => 'fixed',
		   );
	$i++;
    }
    $TEXT->yview('end');

} # end update_function_list

} # end subroutine plop
