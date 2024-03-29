package main;

unshift(@INC, "../..");

use Tk;
use English;
use Carp;

require Tk::DialogBox;
require Tk::NoteBook;
require Tk::LabEntry;

print "1..1";
$name = "Rajappa Iyer";
$email = "rsi\@netcom.com";
$os = "Linux";

outer:
{
    $top = MainWindow->new;
    $pb = $top->Button(-text => "Notebook", -command => \&donotebook);
    $eb = $top->Button(-text => "Exit", -command => sub {print "ok 1\n"; exit;});
    $pb->pack;
    $eb->pack;
    MainLoop;
}

sub donotebook {
    if (not defined $f) {
	# The current example uses a DialogBox, but you could just
	# as easily not use one... replace the following by
	# $n = $top->NoteBook(-ipadx => 6, -ipady => 6);
	# Of course, then you'd have to take care of the OK and Cancel
	# buttons yourself. :-)
	$f = $top->DialogBox(-title => "Personal Profile",
			     -buttons => ["OK", "Cancel"]);
	$n = $f->add(NoteBook, -ipadx => 6, -ipady => 6);

	$address_p = $n->add("address", -label => "Address", -underline => 0);
	$pref_p = $n->add("pref", -label => "Preferences", -underline => 0);
	
	$address_p->LabEntry(-label => "Name:             ",
	     -labelPack => [-side => "left", -anchor => "w"],
	     -width => 20,
	     -textvariable => \$name)->pack(-side => "top", -anchor => "nw");
	$address_p->LabEntry(-label => "Email Address:",
	     -labelPack => [-side => "left", -anchor => "w"],
	     -width => 50,
	     -textvariable => \$email)->pack(-side => "top", -anchor => "nw");
	$pref_p->LabEntry(-label => "Operating System:",
	     -labelPack => [-side => "left"],
	     -width => 15,
	     -textvariable => \$os)->pack(-side => "top", -anchor => "nw");
	$n->pack(-expand => "yes",
		 -fill => "both",
		 -padx => 5, -pady => 5,
		 -side => "top");
	
    }
    $result = $f->Show;
    if ($result =~ /OK/) {
	print "name = $name, email = $email, os = $os\n";
    }
}

