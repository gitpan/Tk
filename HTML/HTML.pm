require Tk::Table;
package Tk::HTML::FORM;
use Carp;
use strict qw(vars subs);
use Tk::Pretty;

sub RESET;
sub PASSWORD;
sub SUBMIT;

sub encode 
{
 my $class = shift;
 my $a = shift;
 $a =~ s/\n/\015\012/gm;
 $a =~ s/([^0-9A-Za-z ])/sprintf('%%%02X',ord($1))/egm;
 $a =~ s/ /+/gm;
 return $a;
}

sub Owner
{
 return shift->{'Owner'};
}

sub Variable
{
 my ($form,$args) = @_;
 my $name = $args->{'NAME'};
 my @pair = ($name,undef);
 push(@{$form->{'Values'}},\@pair);
 return \$pair[1];
}

sub Reset
{
 my ($f) = @_;
 my ($a,$b);
 my $r = $f->{'Reset'};
 my $v = $f->{'Values'};
 my $i;
 for ($i= 0; $i < @$v; $i++)
  {
   if (ref($v->[$i][1]))
    {
     $v->[$i][1]->Call($r->[$i]);
    }
   else
    {
     $v->[$i][1] = $r->[$i];
    }
  }
}

sub link_text 
{
  my($f,$e) = @_;
  my @t = @{$f->{'LINKED_TEXT'}};
  my $i;
  for($i=0;$i<=$#t;$i++) 
   {
    last if $t[$i] == $e;
   }
  $i++;
  $i = 0 if $i > $#t;
  $t[$i]->focus();
}

sub TEXT
{
 my ($form,$args) = @_;
 my $w = $form->Owner;
 my $var = $form->Variable($args);
 $$var= $args->{'VALUE'};
 my $e = $w->Entry(-relief => 'sunken', -textvariable => $var );
 push(@{$form->{'LINKED_TEXT'}},$e);
 $e->bind('<Return>' => [$form,'link_text',$e]);
 $e->configure(-width => $args->{'SIZE'}) if defined $args->{'SIZE'};
 $e->configure(-show => '*') if $args->{'TYPE'} =~ /PASSWORD/i;
 $w->window('create','insert',-window => $e);
 $w->{NL} = 0;                
}

*PASSWORD = \&TEXT;

sub Button
{
 my ($form,$args) = @_;
 my $w = $form->Owner;
 my $type = $args->{'TYPE'};
 my $method = "\u\L$type";
 my $text   = $method;
 $text = $args->{'VALUE'} if defined $args->{'VALUE'};
 if(defined $args->{'NAME'}) 
  {
   my $var = $form->Variable($args);
   $$var = $args->{'VALUE'} if defined $args->{'VALUE'};
  }
 my $e = $w->Button(-text => $text, -command => [$form,$method]);
 $w->window('create','insert',-window => $e);
 $w->{NL} = 0;                
}

*SUBMIT = \&Button;
*RESET  = \&Button;

sub CHECKBOX
{
 my ($form,$args) = @_;
 my $w = $form->Owner;
 my $var = $form->Variable($args);
 $args->{'VALUE'} = 1 unless (defined $args->{'VALUE'});
 ${$var} = (defined $args->{'CHECKED'})?$args->{'VALUE'}: undef;
 my $e = $w->Checkbutton(-variable => $var, -onvalue => $args->{'VALUE'}, -offvalue => undef);
 $w->window('create','insert',-window => $e);
 $w->{NL} = 0;                
}

sub RadioValue
{
 my ($bv,$val) = @_;
 $$bv = $val if (@_ > 1);
 return $$bv;
}

sub RADIO
{
 my ($form,$args) = @_;
 my $w = $form->Owner;
 $form->{'RadioVars'} = {} unless (exists $form->{'RadioVars'});
 my $name = $args->{'NAME'};
 $name = '__NONAME__' unless (defined $name);
 unless (exists $form->{'RadioVars'}{$name})
  {
   my $var = $form->Variable($args);
   $$var = Tk::Callback->new([\&RadioValue,\$form->{'RadioVars'}{$name}]);
  }
 my $bv = \$form->{'RadioVars'}{$name};
 $$bv = $args->{'VALUE'} if (!defined $$bv || defined $args->{'SELECTED'});
 my $e = $w->Radiobutton(-variable => $bv, -value => $args->{'VALUE'});
 $w->window('create','insert',-window => $e);
 $w->{NL} = 0;                
}

sub HIDDEN
{
 my ($form,$args) = @_;
 my $var = $form->Variable($args);
 $$var = $args->{'VALUE'};  
}

sub IMAGE
{
 my ($form,$args) = @_;
 my $w = $form->Owner;
 my $n = $args->{'NAME'};
 if(defined $args->{'NAME'} && defined $args->{'SRC'}) 
  {
   $args->{'IMAGE'} = $form;
   $w->IMG($form,$args);
  }
}

sub OptionValue
{
 my ($mb,$var) = @_;
 my $val = $$var;
 if (exists $mb->{FORM_MAP})
  {
   $val = $mb->{FORM_MAP}{$val} if (exists $mb->{FORM_MAP}{$val});
  }
 return $val;
}

sub MultipleValue
{
 my ($lb,$name) = @_;
 my $index;
 my @val = ();
 foreach $index ($lb->curselection)
  {
   if (exists $lb->{FORM_MAP} && defined $lb->{FORM_MAP}[$index])
    {
     push(@val, $lb->{FORM_MAP}[$index]);
    }
   else
    {
     push(@val, $lb->get($index));
    }
  }
 return @val;
}

sub Submit
{
 my($f) = shift;
 my @query = @_;
 my $w = $f->Owner;
 my $action = $f->{'ACTION'};
 my $method = $f->{'METHOD'};
 $method = 'GET' unless (defined $method);
 $action = ''    unless (defined $action);
 my $what;
 foreach $what (@{$f->{'Values'}})
  {
   my ($a,$b) = @$what;
   my @val = (ref $b) ? $b->Call : $b;
   foreach $b (@val)
    {
     push(@query,"$a=" . $f->encode($b)) if (defined $b); 
    }
  }
 my $query = join('&',@query); 
 if ($method eq "POST") 
  {
   $w->HREF($method,$action,$query);
  } 
 else 
  {
   $w->HREF($method,"$action?$query");
  }
}

package Tk::HTML;
use Carp;
use strict qw(vars subs);
use Tk::Pretty;
use AutoLoader;

%Tk::HTML::Special = ('lt' => '<', 'gt' => '>', 'amp' => '&', 
                      'quot' => '"',
                      'Aacute' => "\301", 'Agrave' => "\300", 'Acirc' => "\302", 
                      'Atilde' => "\303", 'Aring' => "\305", 'Auml' => "\304", 
                      'AElig' => "\306", 'Ccedil' => "\307", 'Eacute' => "\311",
                      'Egrave' => "\310", 'Ecirc' => "\312", 'Euml' => "\313",
                      'Iacute' => "\315", 'Igrave' => "\314", 'Icirc' => "\316",
                      'Iuml' => "\317", 'ETH' => "\320", 'Ntilde' => "\321",
                      'Oacute' => "\323", 'Ograve' => "\322", 'Ocirc' => "\324",
                      'Otilde' => "\325", 'Ouml' => "\326", 'Oslash' => "\330",
                      'Uacute' => "\332", 'Ugrave' => "\331", 'Ucirc' => "\333",
                      'Uuml' => "\334", 'Yacute' => "\335", 'THORN' => "\336",
                       'szlig' => "\337", 'aacute' => "\341", 'agrave' => "\340",
                       'acirc' => "\342", 'atilde' => "\343", 'atilde' => "\343",
                       'auml' => "\344", 'aelig' => "\346", 'ccedil' => "\347",
                       'eacute' => "\351", 'egrave' => "\350", 'ecirc' => "\352",
                       'euml' => "\353", 'iacute' => "\355", 'igrave' => "\354",
                       'icirc' => "\356", 'iuml' => "\357", 'eth' => "\360",
                       'ntilde' => "\361", 'oacute' => "\363", 'ograve' => "\362",
                       'ocirc' => "\364", 'otilde' => "\365", 'ouml' => "\366",
                       'oslash' => "\370", 'uacute' => "\372", 'ugrave' => "\371",
                       'ucirc' => "\373", 'uuml' => "\374", 'yacute' => "\375",
                       'thorn' => "\376", 'yuml' => "\377");


%Tk::HTML::FontTag = ('CITE' => 'I', 'STRONG' => 'B', 'EM' => 'B', 
                      'TT' => 'KBD', 'SAMP' => 'CODE');

sub GenTag
{
 my $w = shift;
 my $prefix = shift;
 my $tag = $prefix . ++$w->{Count};
 $w->{'GenTag'} = [] unless (exists $w->{'GenTag'});
 push(@{$w->{'GenTag'}},$tag);
 $w->tag('configure',$tag,@_) if (@_);
 return $tag;
}

sub CurrentForm
{
 my ($w,$f) = @_;
 if (@_ > 1)
  {
   $w->{'CurrentForm'} = $f;
  }
 return $w->{'CurrentForm'};
}

sub Cleanout
{
 my ($w) = @_;
 $w->{NL} = 2;
 $w->{Count} = 0;
 $w->{TAGS} = {};
 $w->{'List'} = [];
 if (exists $w->{'GenTag'})
  {
   my @gen = @{delete($w->{'GenTag'})};
  }
 $w->delete('0.0','end');
 $w->{'BODY'}   = 1;
 $w->{'FORM'}   = []; # all forms defined for this document
 $w->{'Text'}   = []; # Current place to send Text
 $w->{'Option'} = []; # Current place to send Option
}

sub Font
{
 my ($w,%fld)    = @_;
 $fld{'family'}  = 'times'  unless (exists $fld{'family'});
 $fld{'weight'}  = 'medium' unless (exists $fld{'weight'});
 $fld{'slant'}   = 'r'      unless (exists $fld{'slant'});
 $fld{'size'}    = 140      unless (exists $fld{'size'});
 $fld{'spacing'} = '*'     unless (exists $fld{'spacing'});
 $fld{'slant'}   = substr($fld{'slant'},0,1);
 my $name = "-*-$fld{'family'}-$fld{'weight'}-$fld{'slant'}-*-*-*-$fld{'size'}-*-*-$fld{'spacing'}-*-iso8859-1";
 return $name;
}

sub nl
{
 my ($w,$n) = @_;
# print "Got ",$w->{'NL'}," need $n for ",join(',',caller(1)),"\n";
 while ($w->{'NL'} < $n)
  {
   $w->insert('insert',"\n");
   $w->{'NL'}++;
  }
}

sub call_ISINDEX 
{
 my($w,$e) = @_;
 my $method = "GET";
 my $url;
 if(defined $w->{'base'}) { $url = $w->{'base'}; } else { $url = $w->url; }
 my $query = Tk::HTML::FORM::encode($w,$e->get);
 $w->HREF('GET',"$url?$query");
}

sub FindImage
{
 my ($w,$src,$l) = @_;
 $src = $w->HREF('GET',$src);
 my $img;
 eval { $img = $w->Pixmap(-data => $src) };
 eval { $img = $w->Bitmap(-data => $src) } if ($@);
 eval { $img = $w->Photo(-data => $src)  } if ($@);
 if ($@)
  {
   warn "$@";
  }
 else
  {
   $l->configure(-image => $img);
  }
}

sub IMG_CLICK 
{
 my($w,$c,$t,$aref,$n) = @_;
 my $Ev = $c->XEvent;
 my $cor = $c->cget(-borderwidth);
 if($t eq "ISMAP") 
  {
   $w->HREF('GET',$aref . "?" . ($Ev->x - $cor) . "," . ($Ev->y - $cor));
  } 
 elsif($t eq "AREF")
  {
   $w->HREF('GET',$aref);
  }
 else 
  {
   my $s = "$n.x=" . ($Ev->x - $cor) . "&$n.y=" . ($Ev->y - $cor);
   $aref->Submit($s);
  }
}

# --------------------------------------------------------------------------
# Now methods called to handle HTML tags
# --------------------------------------------------------------------------

sub Heading
{
 my ($w,$f,$args) = @_;
 $w->nl(2);
 if (!$f)
  {
   if (exists $args->{'ALIGN'})
    {
     $w->tag('configure',$args->{Tag},-justify => "\L$args->{'ALIGN'}") 
    }
   $w->tag('add',$args->{'Tag'},$args->{Start},$args->{End});
  }
 return $w;
}

*H1   = \&Heading; *H2   = \&Heading; *H3   = \&Heading;
*H4   = \&Heading; *H5   = \&Heading; *H6   = \&Heading;

sub BLOCKQUOTE
{
 my ($w,$f,$args) = @_;
 if ($f)
  {
   $w->nl(1);
  }
 else
  {
   $w->tag('add',$args->{Tag},$args->{Start},$args->{End});
   $w->nl(1);
  }
 return $w;
}

sub CENTER
{
 my ($w,$f,$args) = @_;
 if ($f)
  {
   $w->nl(1);
  }
 else
  {
   $w->tag('add',$args->{Tag},$args->{Start},$args->{End});
   $w->nl(1);
  }
 return $w;
}

sub BLINK
{
 my ($w,$f,$args) = @_;
 return $w;
}

sub ADDRESS
{
 my ($w,$f,$args) = @_;
 return $w;
}

sub HTML
{
 my ($w,$f,$args) = @_;
 return $w;
}

sub B; sub I; sub TT;
sub CODE;
sub CITE;
sub VAR;
sub DFN;
sub KBD;
sub EM;
sub SAMP;
sub STRONG;

sub LINK;
sub MENU;
sub DIR;
sub LIMENU;
sub LIDIR;

sub H1;
sub H2;
sub H3;
sub H4;
sub H5;
sub H6;

sub FontTag
{
 my ($w,$f,$args) = @_;
 if (!$f)
  {
   my $tag = $args->{Tag};
   $tag = $Tk::HTML::FontTag{$tag} if (exists $Tk::HTML::FontTag{$tag});
   $w->tag('add',$tag,$args->{Start},$args->{End});
  }
 return $w;
}

*B      = \&FontTag;         *EM     = \&FontTag;
*I      = \&FontTag;         *VAR    = \&FontTag;
*SAMP   = \&FontTag;         *CITE   = \&FontTag;
*CODE   = \&FontTag;         *DFN    = \&FontTag;
*KBD    = \&FontTag;         *TT     = \&FontTag;
*STRONG = \&FontTag;         

sub IMG
{
 my ($w,$f,$args) = @_;
 my $alt = ">>Missing IMG<<";
 $alt = $args->{'ALT'} if (exists $args->{'ALT'});
 my $l = $w->Label(-text => $alt);
 my $al = $args->{'ALIGN'};
 my @al = (-align => 'baseline');
 if (defined $al)
  {
   my $al = "\U$al";
   if ($al eq "MIDDLE")
    {
     @al = (-align => 'center') 
    }
   elsif ($al eq "BOTTOM")
    {
     @al = (-align => 'baseline') 
    }
   elsif ($al eq "TOP")
    {
     @al = (-align => 'top') 
    }
   else
    {
     print "Align '$al'?\n";
    }
  }
 $w->window('create','insert','-window' => $l, @al);
 $w->{NL} = 0;                
 $w->FindImage($args->{'SRC'},$l) if (exists $args->{'SRC'});
 if(defined $args->{'IMAGE'} || 
    (exists $w->{TAGS}{'A'} && @{$w->{TAGS}{'A'}}))
  {
   $l->configure('-cursor' => "top_left_arrow", -borderwidth => 3, -relief => 'raised');
   if(defined $args->{'ISMAP'})
    {
     $l->bind('<1>',[$w,'IMG_CLICK',$l,'ISMAP',${$w->{TAGS}{'A'}}[0]->{'HREF'}]);
    } 
   elsif(defined $args->{'IMAGE'})
    {
     $l->bind('<1>',[$w,'IMG_CLICK',$l,'IMAGE',$f,$args->{'NAME'}]);
    } 
   else
    {
     $l->bind('<1>',[$w,'IMG_CLICK',$l,'AREF',${$w->{TAGS}{'A'}}[0]->{'HREF'}]);
    }
  }
 return $w;
}

sub TITLE
{
 my ($w,$f,$args) = @_;
 $w->{'BODY'} = 0;
 return $w;
}

sub BODY
{
 my ($w,$f,$args) = @_;
 $w->{'BODY'} = 1;
 return $w;
}

sub HEAD
{
 my ($w,$f,$args) = @_;
 $w->{'BODY'} = 0;
 return $w;
}

sub P
{
 my ($w,$f,$args) = @_;
 $w->{'BODY'} = 1;
 $w->nl(2);
 return $w;
}

sub BR
{
 my ($w,$f,$args) = @_;
 $w->{'BODY'} = 1;
 if (@{$w->{'Text'}})
  {
   $w->{'Text'}[-1]->Call("\n");
  }
 else
  {
   $w->nl(1);
  }
 return $w;
}

sub HR
{
 my ($w,$f,$args) = @_;
 my $r = $w->Frame(-height => 3, 
                   -width => $w->cget('-width')*140,
                   -borderwidth => 1, -relief => 'raised',
                   -background => 'black'
                  );
 $w->nl(1);
 $w->window('create','insert','-window' => $r, -pady => 0, -padx => 0);
 $w->{NL} = 0;
 $w->{'BODY'} = 1;
 $w->nl(1);
 return $w;
}




sub FORM
{
 my ($w,$f,$form) = @_;
 $w->{'body'} = 1;
 if ($f)
  {
   $form->{OldForm} = $w->CurrentForm;
   bless $form,'Tk::HTML::FORM';
   push(@{$w->{'FORM'}},$form);
   $form->{'Values'}  = [];
   $form->{'Owner'} = $w;
   $w->CurrentForm($form);
  }
 else
  {
   my $what;
   my @val = ();
   foreach $what (@{$form->{'Values'}})
    {
     my $val = $what->[1];
     if (ref($val))
      {
       $val = $val->Call();
      }
     push(@val,$val);
    }
   $form->{'Reset'} = \@val;
   $w->CurrentForm(delete $form->{OldForm});
  }
 $w->nl(1);
 return $w;
}

sub INPUT 
{
  my($w,$f,$args) = @_;
  my $form = $w->CurrentForm;
  my $type = $args->{'TYPE'};
  print Pretty($args),"\n";
  $args->{'TYPE'} = $type = 'TEXT' unless (defined $type);
  $type = "\U$type";
  $form->$type($args);
  return $w;
}

sub OPTION 
{
 my($w,$f,$args) = @_;
 return $w;
}

sub OptionText
{
 my ($w,$mb,$text) = @_;
 $text =~ s/^\s+//;
 $text =~ s/\s+$//;
 if (exists $w->{TAGS}{'OPTION'} && @{$w->{TAGS}{'OPTION'}})
  {
   my $args = pop(@{$w->{TAGS}{'OPTION'}});       
   $args = {} unless (defined $args);
   $args->{'VALUE'} = $text unless (exists $args->{'VALUE'});
   if ($args->{'VALUE'} ne $text)
    {                  
     $mb->{'FORM_MAP'} = {} unless (exists $mb->{'FORM_MAP'});
     $mb->{'FORM_MAP'}{$text} = $args->{'VALUE'};
    }                  
   $mb->options([$text]);
   $mb->setOption($text) if (defined $args->{'SELECTED'});
  }
 else
  {
   &Tk::Pretty::PrintArgs if (length $text);
  }
}

sub MultipleText
{
 my ($w,$lb,$text) = @_;
 $text =~ s/^\s+//;
 $text =~ s/\s+$//;
 if (exists $w->{TAGS}{'OPTION'} && @{$w->{TAGS}{'OPTION'}})
  {
   my $args = pop(@{$w->{TAGS}{'OPTION'}});       
   my $index = $lb->index('end');
   $args = {} unless (defined $args);
   $args->{'VALUE'} = $text unless (exists $args->{'VALUE'});
   if ($args->{'VALUE'} ne $text)
    {                        
     $lb->{'FORM_MAP'} = [] unless (exists $lb->{'FORM_MAP'});
     $lb->{'FORM_MAP'}[$index] = $args->{'VALUE'};
    }                        
   $lb->insert($index,$text);
   $lb->selection('set',$index) if (defined $args->{'SELECTED'});
  }
 else
  {
   &Tk::Pretty::PrintArgs if (length $text);
  }
}

sub SELECT 
{
 my($w,$f,$args) = @_;
 if ($f) 
  {
    my $form = $w->CurrentForm;
    if (defined $args->{'MULTIPLE'} || (defined $args->{'SIZE'} && $args->{'SIZE'} > 1)) 
     {
      my $f = $w->Frame;
      my $s = $f->Scrollbar;
      my $size = 15;
      $size = $args->{'SIZE'} if defined $args->{'SIZE'};
      my $e = $f->Listbox(-height => $size,
                       -yscrollcommand => ['set',$s], -setgrid => 1);;
      $e->configure(-selectmode => 'multiple') if defined $args->{'MULTIPLE'};
      $e->pack(-side => 'left', -expand => 'yes', -fill => 'both');
      $f->AddScrollbars($e);
      $f->configure(-scrollbars => 'e');
      $w->window('create','insert',-window => $f);
      $w->{NL} = 0;
      if (defined $form)
       {
        my $var = $form->Variable($args);
        $$var   = Tk::Callback->new([\&Tk::HTML::FORM::MultipleValue,$e]);
       }
      push(@{$w->{'Text'}},Tk::Callback->new([\&MultipleText,$w,$e]));
     } 
    else 
     {
      my $buttonvar = "__not__";
      my $mb = $w->Optionmenu(-textvariable => \$buttonvar,-relief => 'raised',
                              -indicatoron => 1);
      $w->window('create','insert',-window => $mb);
      $w->{NL} = 0;                
      if (defined $form)
       {
        my $var = $form->Variable($args);
        $$var   = Tk::Callback->new([\&Tk::HTML::FORM::OptionValue,$mb,\$buttonvar]);
       }
      push(@{$w->{'Text'}},Tk::Callback->new([\&OptionText,$w,$mb]));
     }
   } 
  else 
   {
    pop(@{$w->{'Text'}});
   }
 return $w;
}

sub TEXTAREA {
  my($w,$f,$args) = @_;
  if ($f) 
   {
    my $rows = (defined $args->{'ROWS'})?$args->{'ROWS'}:20;
    my $cols = (defined $args->{'COLS'})?$args->{'COLS'}:12;
    my $form = $w->CurrentForm;
    $args->{'NAME'} = '__inconnu__' if ! defined $args->{'NAME'};
    my $f = $w->Frame;
    my $t = $f->Text( -wrap => 'none',  -relief => 'sunken', -width => $cols, -height => $rows);
    $t->pack(-expand => 'yes', -fill => 'both');
    $f->AddScrollbars($t);
    $f->configure(-scrollbars => 'se');
    $w->{'textarea'} = $t;
    if (defined $form)
     {
      my $var = $form->Variable($args);
      $$var   = Tk::Callback->new([$t,'Contents']);
     }
    $w->window('create','insert',-window => $f);
    $w->{NL} = 0;
    push(@{$w->{'Text'}},Tk::Callback->new([$t,'insert','end']));
   } 
  else 
   {
    pop(@{$w->{'Text'}});
   }
 return $w;
}


  
sub BASE 
{
 my($w,$f,$args) = @_;
 $w->{'BODY'} = 0;
 $w->{'base'} = $args->{'HREF'} if defined $args->{'HREF'};
 return $w;
}

sub ISINDEX 
{
  my($w,$f,$args) = @_;
  $w->{'body'} = 0;
  $w->HR($w,$f,$args);
  $w->insert('end','This is a searchable index : ');
  my $e = $w->Entry;
  $e->bind('<Return>',[$w,'call_ISINDEX',$e]);
  $w->window('create','end',-window => $e);
  $w->{NL} = 0;
  $w->HR($w,$f,$args);
  return $w;
}

sub A
{
 my ($w,$f,$args) = @_;
 if (!$f)
  {
   if (exists $args->{'HREF'})
    {
     my $href = $args->{'HREF'};
     my $tag  = $w->GenTag('HREF',-underline => 1);
     $w->tag('add',$tag,$args->{Start},$args->{End});
     $w->tag('bind',$tag,'<Button-1>',[$w,'HREF','GET',$href]);
     $w->tag('bind',$tag,'<Enter>',[$w,'ShowLink',$href]);
    }
   if (exists $args->{'NAME'})
    {
     my $name = $args->{'NAME'};
     $w->tag('add',$name,$args->{Start},$args->{End});
     push(@{$w->{'GenTag'}},$name);
    }
  }
 return $w;
}

*LINK = \&A;

sub List
{
 my ($w,$f,$args) = @_;
 if ($f)
  {
   push(@{$w->{'List'}},['LI' . $args->{Tag},0,$args->{Start}]);
   my $depth = @{$w->{'List'}};
   if($depth > 1) {
     my $len = ($depth - 1) * 20;
     my $tag = $w->GenTag($args->{Tag} . "temp",
                          -lmargin1 => $len, 
                          -lmargin2 => $len,
                          -rmargin => $len);
     $w->tag('add',$tag,${${$w->{'List'}}[$depth-2]}[2],${${$w->{'List'}}[$depth-1]}[2]);
   }
  }
 else
  {
   my $depth = @{$w->{'List'}};
   if($depth > 1) {
     ${${$w->{'List'}}[$depth - 2]}[2] = $args->{End};
     my $len = $depth * 20;
     my $tag = $w->GenTag($args->{Tag},
                          -lmargin1 => $len, 
                          -lmargin2 => $len,
                          -rmargin => $len);
     $w->tag('add',$tag,${${$w->{'List'}}[$depth - 1]}[2],$args->{End});
   }
   pop(@{$w->{'List'}});
  }
 return $w;
}

sub DL;
sub UL;
sub OL;

*DL   = \&List;
*UL   = \&List;
*MENU = \&List;
*DIR  = \&List;
*OL   = \&List;

sub LIUL
{
 my ($w,$n,$args) = @_;
 $w->nl(1);
 my $l = $w->Label(-text => 'O');
 unless (exists $w->{'ULimage'})
 {
  $w->{'ULimage'} = $w->Photo(-file => Tk->findINC('/HTML/LIUL.gif'));
 }
 $l->configure(-image => $w->{'ULimage'}) if (defined $w->{'ULimage'});
 $w->window('create','insert','-window' => $l);
 $w->{NL} = 0;
 return $n;
}

*LIMENU = \&LIUL;
*LIDIR  = \&LIUL;

sub LIOL
{
 my ($w,$n,$args) = @_;
 $n++;
 $w->insert('insert',"\n $n. ");
 return $n;
}

sub LI
{
 my ($w,$f,$args) = @_;
 if (@{$w->{'List'}})
  {
   my ($kind,$num) = @{$w->{'List'}[-1]};
   $num = $w->$kind($num,$args);
   $w->{'List'}[-1][1] = $num;
  }
 return $w;
}

sub DT
{
 my ($w,$f,$args) = @_;
 $w->nl(2);
 return $w;
}

sub DD
{
 my ($w,$f,$args) = @_;
 $w->nl(1);
 return $w;
}

sub Enclosing
{
 my ($w,$tag) = @_;
 return $w->{TAGS}{$tag}[-1] if (exists $w->{TAGS}{$tag} && @{$w->{TAGS}{$tag}});
 croak "No enclosing $tag";
}

sub TR
{
 my ($w,$f,$args) = @_;
 my $table = $w->Enclosing('TABLE');
 if ($f)
  {
   $args->{Col} = 0;
  }
 else
  {
   $table->{Widget}->configure(-columns => $args->{Col});
   $table->{Row}++;
  }
 return $w;
} 

sub TD
{
 my ($w,$f,$args) = @_;
 my $row   = $w->Enclosing('TR');
 my $table = $w->Enclosing('TABLE');
 if ($f)
  {
   $args->{Text} = "";
   push(@{$w->{'Text'}},Tk::Callback->new(sub { $args->{Text} .= shift }));
  }
 else
  {
   my $w = $table->{Widget};
   my @args = ();
   my $al = $args->{ALIGN};
   if (defined $al)
    {
     push(@args,-justify => 'right',-anchor => 'e') if ($al =~ /RIGHT/i);
    }
#  print $table->{Row},",",$row->{Col}," : ",$args->{Text},"\n";
   $w->Create($table->{Row},$row->{Col},'Message',-aspect => 300, 
           -relief => 'ridge', -text => $args->{Text},@args);
   pop(@{$w->{'Text'}});
   $row->{Col}++;
  }
 return $w;
} 

*TH = \&TD;

sub TABLE
{
 my ($w,$f,$args) = @_;
 if ($f)
  {
   $args->{Widget} = $w->ScrlTable;
   $args->{Row}    = 0;
   $w->window('create','insert',-window => $args->{Widget});
   print "Table:",Pretty($args),"\n";
  }
 else
  {
#   $args->{Widget}->configure(-rows => $args->{Row});
  }
 return $w;
}

sub PRE
{
 my ($w,$f,$args) = @_;
 $w->{'PRE'} = $f;
 if (!$f)
  {
   $w->tag('add','CODE',$args->{Start},$args->{End});
  }
 return $w;
}

sub Special
{
 my ($code) = @_;
 return $Tk::HTML::Special{$code} if (exists $Tk::HTML::Special{$code});
 print "Don't know &$code;\n";
 return "&$code;";
}

sub HTML::dump {
  my($a,$b) = @_;
  ${($a->configure(-textvariable))[4]} = $b;
}

sub Text
{
 my ($w,$text) = @_;
 return unless (defined(substr($text,0,1)) && $w->{'BODY'});
 if (@{$w->{'Text'}})
  {
   $w->{'Text'}[-1]->Call($text);
  }
 else
  {
   unless ($w->{'PRE'})
    {
     $text =~ s/^\s+//;
     $text =~ s/\s+$//;
     $text =~ s/\s\s+/ /;
    }
   $text =~ s/&(\w+);?/Special($1)/ge;
   $text =~ s/&#(\d+);?/chr($1)/ge;
   if (length(substr($text,0,1)))
    {
     $text =~ s/\n//mg unless $w->{'PRE'};
     $w->insert('insert',' ',qw(text)) unless ($w->{NL});
     $w->insert('insert',$text,qw(text));
     $w->{NL} = 0;                
     $w->{NL} = 1 if ($text =~ /\n$/);
    }
  }
}

sub CloseTag
{
 my ($w,$tag) = @_;
 my $info = pop(@{$w->{TAGS}{$tag}});       
 $info->{End} = $w->index('insert');
 return $w->$tag(0,$info);
}

%Tk::HTML::NotNested = ( 'TD' => 1 );

sub Tag
{                      
 my ($w,$tag) = @_;
 return $w if ($tag =~ /^<!/);
 my $val = $w;
 if ($tag =~ m#^</(\w+)>$#)
  {
   $tag = "\U$1";
   if (exists $w->{TAGS}{$tag} && @{$w->{TAGS}{$tag}})
    {
     $w->CloseTag($tag);
    }
   else
    {
     warn "Missmatched </$tag>";
    }
  }
 elsif ($tag =~ /^<(\w+)(\s+[^\0]*)*>$/)
  {
   $tag = "\U$1";
   my $args = $2;
   my %info = (Start => $w->index('insert'),Tag => $tag);
   if (defined $args)
    {
     while ($args =~ /^\s+(\w+)\s*(?:=\s*("[^"]*"|[^"\s]+)|)([^\0]*)$/x)
      {
       my($name,$val) = ("\U$1",$2);
       $val = " " if !defined $2;
       $args = " $3";
       $val  =~ s/^"([^\0]*)"$/$1/;
       $info{$name} = $val;
      }
    }
   unless (exists $w->{TAGS}{$tag})
    {                
     $w->{TAGS}{$tag} = [];
    }                
   if (exists($Tk::HTML::NotNested{$tag}) && @{$w->{TAGS}{$tag}})
    {
     $w->CloseTag($tag);
    }
   push (@{$w->{TAGS}{$tag}},\%info);
   $val = $w->$tag(1,\%info);
  }
 else
  {
   warn "Ignore $tag";
  }
 croak "$tag" unless (ref $val);
 return $val;
}

sub plain
{
 my ($w,$text) = @_; 
 my $var = \$w->{Configure}{-plain};
 if (@_ > 1)
  {
   $$var = $text;
   $w->Cleanout;
   $w->insert('end',$text);
  }
 return $$var;

}

sub html
{
 my ($w,$html) = @_; 
 my $var = \$w->{Configure}{-html};
 if (@_ > 1)
  {
   $$var = $html;
   $w->Cleanout;
   my $data;
   foreach $data (split(/(<[^\0]*?>)/,$html))
    {
     if (substr($data,0,1) eq '<')
      {
       $w = $w->Tag($data);
      }
     else
      {
       $w->Text($data);
      }
    }
  }
 return $$var;
}

sub file
{
 my ($w,$file) = @_; 
 my $var = \$w->{Configure}{-file};
 if (@_ > 1)
  {
   open($file,"<$file") || croak "Cannot open $file:$!";
   $$var = $file;
   my $data;
   $w->html(join('',<$file>));
   close($file);
  }
 return $$var;
}

1;

__END__


