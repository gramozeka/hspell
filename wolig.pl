#!/usr/bin/perl -w
#
# Copyright (C) 2000-2002 Nadav Har'El, Dan Kenigsberg
#
#BEGIN {push @INC, (".")}
use Carp;
use FileHandle;

my ($fh,$word,$optstring,%opts);

sub outword {
  my $word = shift;
  # change otiot-sofiot in the middle of the word
  $word =~ s/�(?=[�-�])/�/go;
  $word =~ s/�(?=[�-�])/�/go;
  $word =~ s/�(?=[�-�])/�/go;
  $word =~ s/�(?=[�-�])/�/go;
  $word =~ s/�(?=[�-�])/�/go;
  print $word."\n";
}

##################################### ROUTINES FOR VERB CONJUGATION ########
#guf constants (any idea for a better declaration in perl?)
my ($ani, $ata, $at, $hu, $hi, $anu, $atem, $aten, $hem, $hen) =
        (1,2,3,4,5,6,7,8,9,10);
sub legal_guf {
  my $tense = shift;

  if ($tense==$past) {return ($ani,$ata,$hu,$hi,$anu,$atem,$aten,$hem) }
  elsif ($tense==$present) {return ($ata,$at,$atem,$aten) }
  elsif ($tense==$future) {
    return ($ani,$ata,$at,$hu,$anu,$atem,$aten,$hem) }
  elsif ($tense==$imperative) {return ($ata,$at,$atem,$aten) }
  else {return $ani};
}
# same for binyan
my @all_binyan = 
        ($qal, $nifgal, $pigel, $pugal, $hitpagel, $hifgil, $hufgal) =
        (101,102,103,104,105,106,107);
my @all_tense = 
        ($past, $present, $future, $imperative, $maqor, $shempoal) =
        (201,202,203,204,205,206,207);
## a function like this MUST exist in perl:
sub myinlist {
  my $s = shift;
  foreach $param (@_) {
    return 1 if ($param eq $s);
  }
  return 0;
}

sub sakel_hitpael {
  my $word = shift, $p = shift;
  $word =~ s/�p/p�/ if ($p =~ /�|�/);
  $word =~ s/�p/p�/ if ($p =~ /�/);
  $word =~ s/�p/p�/ if ($p =~ /�/);
  $word =~ s/�p/p/ if ($p =~ /�|�|�/); 
  # todo: sometime the tav is is kept 
  return $word;
}

sub assign_root {
  my ($p, $g, $l, $word) = @_;
  $word =~ s/p/$p/;
  $word =~ s/g/$g/;
  $word =~ s/l/$l/;
  return $word;
}
sub guf_root_clash {
  my ($tense, $guf, $p, $g, $l, $naxe_base) = @_;

  if (($tense==$past) && ($l eq "�")) {
    $naxe_base =~ s/l/�/ if ($guf =~ /$ani|$ata|$anu|$atem|$aten/); 
    $naxe_base =~ s/l/�/ if ($guf =~ /$hi/); 
    $naxe_base =~ s/l// if ($guf =~ /$hem/); 
  }
  if (($tense==$present) && ($l eq "�")) {
    $naxe_base =~ s/l// if ($guf =~ /$atem|$aten/); 
  }
  if (($tense==$future) && ($l eq "�")) {
    $naxe_base =~ s/l// if ($guf =~ /$at|$hem|$atem/); 
    $naxe_base =~ s/l/�/ if ($guf =~ /$aten/); 
  }
  if (($tense==$imperative) && ($l eq "�")) {
    $naxe_base =~ s/l// if ($guf =~ /$at|$atem/); 
    $naxe_base =~ s/l/�/ if ($guf =~ /$aten/); 
  }
  if (($tense==$shempoal) && ($l eq "�")) {
    $naxe_base =~ s/l// if $binyan=~/$hitpagel|$nifgal/ ;
    $naxe_base =~ s/l/�/;
  }
  if (($tense==$maqor) && ($l eq "�")) {
    if ($binyan==$qal) {$naxe_base =~ s/l/�/}
    else {$naxe_base =~ s/l/��/} 
  }
  return $naxe_base;
}

sub binyan_root_clash {
  my ($tense, $binyan, $p, $g, $l, $base) = @_;

  #print "tense=$tense, binyan=$binyan, base $base, hitpael=$hitpagel\n";
  $base = sakel_hitpael($base, $p) if ($binyan==$hitpagel);
  $base =~ s/�// if (length($g)>1) && ($tense==$past);
  $base =~ s/�// if myinlist($binyan, $pigel, $pugal, $hitpagel)
                   && $tense==$present;
  #all
  $base =~ s/p// if (myinlist($binyan,$hifgil,$hufgal) && 
    (($p eq "�" && $g eq "�") || $p eq "�") &&
    !defined($opts{"����_�"})) ;
  return $base;
}

sub binyan_guf_clash {
  my ($tense, $binyan, $guf, $base) = @_;
  
  if ($tense==$past) {
    if (($binyan==$hifgil) && ($guf =~ /$ani|$ata|$at|$anu|$atem|$aten/o))
    { # 1st & 2nd persons don't get yod in hif`il
      $base =~ s/�//;
    }
  }

  if ($tense==$future) {
    if (($binyan==$nifgal) && 
        ($guf =~ /$ani|$ata|$at|$anu|$atem|$aten/o))
    { # 1st & 2nd persons don't get yod in hif`il
      $base =~ s/�//;
    }
    if ($guf==$ani) {
      $base =~ s/�// if ($binyan==$nifgal); 
      $base = "�".$base;
    }
    if ($guf =~ /$at|$atem|$hem/o && $binyan==$qal)
    { # open sylable shortens vav
      $base =~ s/�//;
    }
  }
  if ($tense==$imperative) {
    if (($binyan==$hifgil) && myinlist($guf, $ata, $aten)) {
      $base =~ s/�//;
    } # haf`el and not haf`il
    if ($binyan==$qal && $opts{"��_�����"} &&
        myinlist($guf, $at, $atem)) {
      $base =~ s/�//;} # shimri and not shmori
  } 
  return $base;
}

sub add_guf_affix {
  my ($tense, $guf, $word) = @_;

  if ($tense==$past) {
    $suff = "��" if ($guf==$ani);
    $suff = "�" if ($guf==$ata);
    $suff = "" if ($guf==$hu);
    $suff = "�" if ($guf==$hi);
    if ($guf==$anu) { #if the root ends with nun, don't double it.
      if (substr($word,-1,1) eq "�") { $suff = "�";}
        else { $suff = "��";}
    }
    $suff = "��" if ($guf==$atem);
    $suff = "��" if ($guf==$aten);
    $suff = "�" if ($guf==$hem);
    $word = $word.$suff;
  }

  if ($tense==$present) {
    $suff = "" if ($guf==$ata);
    $suff = "�" if ($guf==$at);
    $suff = "�" if ($guf==$at) && ($binyan==$hifgil); 
    $suff = "" if ($guf==$at) && ($binyan=~/$pigel|$pugal|$hitpagel|$qal/ ) && ($l eq "�"); 
    # this was BAD, passing $l silently
    # todo: this is ugly. must suppy $binyan as param.
    # tdod: many times, both tav and he are applicable.
    $word =~ s/l/�/ if ($guf==$at) && ($binyan==$nifgal); 
    $suff = "��" if ($guf==$atem);
    $suff = "��" if ($guf==$aten);
    $word = $word.$suff;
  }


  if ($tense==$future) {
    $word = "�".$word if ($guf==$ata);
    $word = "�".$word."�" if ($guf==$at);
    # if ($binyan eq "��") { outword $_[0]; } 
    # todo: in nif`al, both yod and double yod are acceptable.
    $word = "�".$word if ($guf==$hu);
    $word = "�".$word if ($guf==$anu);
    $word = "�".$word."�" if ($guf==$atem);
    if ($guf =~ /$aten|$hen/o) {
      $word =~ s/�// if ($binyan==$hifgil);
      if ($l eq "�") {$word = "�".$word."�";}
            else {$word = "�".$word."��";}
    }
    $word = "�".$word."�" if ($guf==$hem);
  }

  if ($tense==$imperative) {
    $word = $word if ($guf==$ata);  # no change
    $word = $word."�" if ($guf==$at);
    $word = $word."�" if ($guf==$atem);
    if ($guf==$aten) {
      if ($l eq "�") {$word = $word."�";}
            else {$word = $word."��";}
    }
  }
  return $word;
}
#############################################################################


my $infile;
if($#ARGV < 0){
	$infile="wolig.dat";
} else {
	$infile=$ARGV[0];
}

$fh = new FileHandle $infile, "r"
  or croak "Couldn't open data file $infile for reading";
while(<$fh>){
  print if /^#\*/;       # print these comments.
  chomp;
  next if /^#/;          # comments start with '#'.
  ($word,$optstring)=split;
  die "Type of word '".$word."' was not specified." if !defined($optstring);
  undef %opts;
  foreach $opt (split /,/o, $optstring){
    $opts{$opt}=1;
  }
  if($opts{"�"}){
    ############################# noun ######################################
    # note that the noun may have several plural forms (see, for example,
    # hege). The default form is "im".
    my $plural_none = $opts{"����"} || substr($word,-3,3) eq "���";
    my $plural_implicit = !($opts{"��"} || $opts{"��"} || $opts{"���"}
			   || $opts{"���"} || $opts{"���"}) && !$plural_none;
    my $plural_iot = $opts{"���"} ||
      ($plural_implicit && (substr($word,-2,2) eq "��"));
    my $plural_xot = $opts{"���"};
    my $plural_ot = $opts{"��"} ||
      ($plural_implicit && !$plural_iot && (substr($word,-1,1) eq "�" || substr($word,-1,1) eq "�" ));
    my $plural_im = $opts{"��"} || ($plural_implicit && !$plural_ot && !$plural_iot);
    my $plural_iim = $opts{"���"};
    # related singular noun forms
    outword $word; # the singular noun itself
    my $smichut=$word;
    my $arye_yud="";
    if(!$opts{"����_�"}){ # replace final � by �, unless ����_� option
      # Academia's relatively-new ktiv male rule, to make smichut ����: �����.
      if(substr($smichut,-2,2) eq "��" && !(substr($smichut,-3,3) eq "���")){
    	$smichut=substr($smichut,0,-2)."���"; # note � replaced by � below.
      }
      if(substr($smichut,-1,1) eq "�" && !$opts{"����_�"}){
        substr($smichut,-1,1)="�";
      }
    } else {
      # Academia's ktiv male rule, to make your lion �����, not ����
      if(substr($smichut,-2,2) eq "��"){
        $arye_yud="�";
      }
    }
    #my $smichut_orig=$smichut;
    if($opts{"�����_��"}){
      # special case:
      # ��, ��, �� include an extra yod in the smichut. Note that in the
      # first person singular possessive, we should drop that extra yod.
      # For a "im" plural, it turns out to be the same inflections as the
      # plural - but this is not the case with a "ot" plural.
      outword $smichut."�-"; # smichut
      outword $smichut."�"; # possessives (kinu'im)
      outword $smichut."���";
      outword $smichut."��";
      outword $smichut."���";
      outword $smichut."���";
      outword $smichut."��";
      outword $smichut."��";
      outword $smichut."���";
      outword $smichut."���";
    } else {
      outword $smichut."-"; # smichut
      if($opts{"�����_��"}){
      	# academia's ktiv male rules indicate that the inflections of ��
	# (at least the plural is explicitly mentioned...) should get an
	# extra yud - to make it easy to distinguish from the number �����.
	substr($smichut,0,-1)=substr($smichut,0,-1).'�';
	substr($word,0,-1)=substr($word,0,-1).'�';
      }
      if(substr($word,-2,2) eq "��"){
      	# in words ending with patach and then the imot kria aleph yud,
	# such as ���� and ����, all the inflections (beside the base word
	# and the smichut) are as if the yud wasn't there.
	# Note that words ending with �� but not patach, like �� and ����,
	# should not get this treatment, so there should be an option to turn
	# it off.
	substr($word,-1,1)="";
	substr($smichut,-1,1)="";
      }
      if($opts{"����_�"}){
      	# the � is dropped from the singular inflections, except one alternate
	# inflection like ����� (the long form of ����):
	$smichut=substr($smichut,0,-1);
        outword $smichut.$arye_yud."��";
      }
      outword $smichut."�"; # possessives (kinu'im)
      outword $smichut.$arye_yud."��";
      outword $smichut.$arye_yud."�";
      outword $smichut.$arye_yud."��";
      outword $smichut.$arye_yud."��";
      outword $smichut."�";
      outword $smichut.$arye_yud."�";
      outword $smichut.$arye_yud."�";
      outword $smichut.$arye_yud."�";
    }
    # related plural noun forms
    # note: don't combine the $plural_.. ifs, nor use elsif, because some
    # nouns have more than one plural forms.
    if($plural_im){
      my $xword=$word;
      if(substr($xword,-1,1) eq "�"){
	# remove final "he" (not "tav", unlike the "ot" pluralization below)
	# before adding the "im" pluralization, unless the ����_� option was
	# given.
	if(!$opts{"����_�"}){
	  $xword=substr($xword,0,-1);
	}
      }
      if($opts{"�����_���"}){
        # when the �����_��� flag is given, we remove the second letter from
	# the word in all the plural inflections
	$xword=substr($xword,0,1).substr($xword,2);
      }
      my $xword_orig=$xword;
      if($opts{"���_�"}){
	# when the ���_� flag was given,we remove the first "em kri'a" from
	# the word in most of the inflections. (see [1, page 42]).
	$xword =~ s/�//o;
      }
      if($opts{"�����_���"}){
	# when the �����_��� flag was given, we change the vowel vav to a
	# consonant vav (i.e., double vav) in most of the inflections.
	# It's nice that we need to make this change for exactly the same
	# forms we needed to do it in the ���_� option case.
	$xword =~ s/�/��/o;
      }
      outword $xword."��";
      $smichut=$xword;
      my $smichut_orig=$xword_orig;
      outword $smichut_orig."�-"; # smichut
      #According to the academia's ktiv male rules (see [3]), the yud in
      #the "�" plural possesive is doubled.
      #outword $smichut."�";
      outword $smichut."��"; # possessives (kinu'im)
      outword $smichut."���";
      outword $smichut."��";
      outword $smichut."���"; # special ktiv male for the feminine
      outword $smichut_orig."���";
      outword $smichut_orig."���";
      outword $smichut."��";
      outword $smichut."��";
      outword $smichut_orig."���";
      outword $smichut_orig."���";
    }
    if($plural_iim){
      # I currently decided that in Hebrew, unlike Arabic, only specific
      # nouns can get the iim (zugi) pluralization, and most nouns can't,
      # e.g., ������� isn't correct (for "two cats") despite a story called
      # ���� ��������. This is why this is an option, and not the default.
      my $xword=$word;
      if(substr($xword,-1,1) eq "�"){
	# Change final he into tav before adding the "iim" pluralization.
	$xword=substr($xword,0,-1)."�";
      }
      my $xword_orig=$xword;
      outword $xword."���";
      $smichut=$xword;
      my $smichut_orig=$xword_orig;
      outword $smichut_orig."�-"; # smichut
      #According to the academia's ktiv male rules (see [3]), the yud in
      #the "�" plural possesive is doubled.
      #outword $smichut."�"; # possessives (kinu'im)
      outword $smichut."��"; # possessives (kinu'im)
      outword $smichut."���";
      outword $smichut."��";
      outword $smichut."���"; # special ktiv male for the feminine
      outword $smichut_orig."���";
      outword $smichut_orig."���";
      outword $smichut."��";
      outword $smichut."��";
      outword $smichut_orig."���";
      outword $smichut_orig."���";
    }
    if($plural_ot){
      my $xword=$word;
      if(substr($xword,-1,1) eq "�" || substr($xword,-1,1) eq "�"){
	# remove final "he" or "tav" before adding the "ot" pluralization,
	# unless the ����_� option was given.
	if(!$opts{"����_�"}){
	  $xword=substr($xword,0,-1);
	}
      }
      if(substr($xword,-2,2) eq "��" || substr($xword,-2,2) eq "��" ){
	# KTIV MALE RULE (should be optional? I'm not sure I agree with them
	# because they make reading ambiguous in exactly the same was a vav
	# or yud was supposed to make not ambiguous).
	# We conveniently apply here two of the Academia's rules of "ktiv
	# male" (as described in [3]):
	# 1) a consonent vav should be doubled, but not when followed by
	#    another vav (so that we don't get 3 vavs in a row). Example �����.
	# 2) don't write yud before yud-vav signifying yu or yo. Example ������
	# Note that we do this after the � rule above.
	$xword=substr($xword,0,-1);
      }
      my $xword_orig=$xword;
      if($opts{"���_�"}){
	# when the ���_� flag was given,we remove the first "em kri'a" from
	# the word in most of the inflections. (see [1, page 42]).
	$xword =~ s/�//o;
      }
      if($opts{"�����_���"}){
	# when the �����_��� flag was given, we change the vowel vav to a
	# consonant vav (i.e., double vav) in most of the inflections.
	# It's nice that we need to make this change for exactly the same
	# forms we needed to do it in the ���_� option case.
	$xword =~ s/�/��/o;
	#$xword =~ s/�/��/o;
      }
      outword $xword."��";
      $smichut=$xword."��";
      my $smichut_orig=$xword_orig."��";
      outword $smichut_orig."-"; # smichut
      #According to the academia's ktiv male rules (see [3]), the yud in
      #the "�" plural possesive is doubled.
      #outword $smichut."�"; # possessives (kinu'im)
      outword $smichut."��"; # possessives (kinu'im)
      outword $smichut."���";
      outword $smichut."��";
      outword $smichut."���"; # special ktiv male for the feminine
      outword $smichut_orig."���";
      outword $smichut_orig."���";
      outword $smichut."��";
      outword $smichut."��";
      outword $smichut_orig."���";
      outword $smichut_orig."���";
    }
    if($plural_iot){
      my $xword=$word;
      if(substr($xword,-1,1) eq "�" || substr($xword,-1,1) eq "�"){
	# remove final "he" or "tav" before adding the "iot" pluralization,
	# unless the ����_� option was given.
	if(!$opts{"����_�"}){
	  $xword=substr($xword,0,-1);
	}
	# remove the letter before that in the special case of the words
	# ����, ���� - in that case the "iot" replaces not only the tav,
	# but also the vav before it.
	if($opts{"�����_����"}){
	  $xword=substr($xword,0,-1);
	}
      }
      outword $xword."���";
      $smichut=$xword."���";
      outword $smichut."-"; # smichut
      #According to the academia's ktiv male rules (see [3]), the yud in
      #the "�" plural possesive is doubled.
      #outword $smichut."�"; # possessives (kinu'im)
      outword $smichut."��"; # possessives (kinu'im)
      outword $smichut."���";
      outword $smichut."��";
      outword $smichut."���"; # special ktiv male for the feminine
      outword $smichut."���";
      outword $smichut."���";
      outword $smichut."��";
      outword $smichut."��";
      outword $smichut."���";
      outword $smichut."���";
    }
    if($plural_xot){
      my $xword=$word;
      if(substr($xword,-1,1) eq "�" || substr($xword,-1,1) eq "�"){
	# remove final "he" or "tav" before adding the "xot" pluralization,
	# unless the ����_� option was given.
	if(!$opts{"����_�"}){
	  $xword=substr($xword,0,-1);
	}
      }
      outword $xword."���";
      $smichut=$xword."���";
      outword $smichut."-"; # smichut
      #According to the academia's ktiv male rules (see [3]), the yud in
      #the "�" plural possesive is doubled.
      #outword $smichut."�"; # possessives (kinu'im)
      outword $smichut."��"; # possessives (kinu'im)
      outword $smichut."���";
      outword $smichut."��";
      outword $smichut."���"; # special ktiv male for the feminine
      outword $smichut."���";
      outword $smichut."���";
      outword $smichut."��";
      outword $smichut."��";
      outword $smichut."���";
      outword $smichut."���";
    }
  } elsif($opts{"�"}){
    ############################# adjective ##################################
    my $xword=$word;
    if(substr($xword,-1,1) eq "�"){
      # remove final "he" before adding the pluralization,
      # unless the ����_� option was given.
      if(!$opts{"����_�"}){
	$xword=substr($xword,0,-1);
      }
    }
    outword $word; # masculin, singular
    outword $word."-"; # smichut (exactly the same as nifrad)
    # feminine, singular:
    if(substr($xword,-1,1) eq "�" || $opts{"����_�"}){
      outword $xword."�";
      outword $xword."�-"; # smichut (exactly the same as nifrad)
    } else {
      outword $xword."�";
      outword $xword."�-"; # smichut
    }
    if($opts{"�"}){
      # special case for adjectives like ����. Unlike the noun case where we
      # turn this option automatically for words ending with ��, here such a
      # default would not be useful because a lot of nouns ending with � or �
      # correspond to adjectives ending with �� that this rule doesn't fit.
      outword $xword."�"; # masculin, plural
      outword $xword."-"; # smichut
    } else {
      outword $xword."��"; # masculin, plural
      outword $xword."�-"; # smichut
    }
    outword $xword."��"; # feminine, plural
    outword $xword."��-"; # smichut (exactly the same as nifrad)
  } elsif($opts{"�"}){
    ################################ verb ####################################
    my $p=substr($word,0,1), $g=substr($word,1,length($word)-2),
       $l=substr($word,-1,1);

    undef %base;
    $base{$past,$qal}="pgl" if ($opts{"��_����"}||$opts{"��_�����"});
    $base{$past,$nifgal}="�pgl" if ($opts{"��"});
    $base{$past,$hifgil}="�pg�l" if ($opts{"��"});
    $base{$past,$hufgal}="��pgl" if ($opts{"��"});
    $base{$past,$pigel}="p�gl" if ($opts{"��"});
    $base{$past,$pugal}="p�gl" if ($opts{"��"});
    $base{$past,$hitpagel}="��pgl" if ($opts{"��"});
    
    $base{$present,$qal}="p�gl" if ($opts{"��_����"}||$opts{"��_�����"});
    $base{$present,$nifgal}="�pgl" if ($opts{"��"});
    $base{$present,$hifgil}="�pg�l" if ($opts{"��"});
    $base{$present,$hufgal}="��pgl" if ($opts{"��"});
    $base{$present,$pigel}="�pgl" if ($opts{"��"});
    $base{$present,$pugal}="�p�gl" if ($opts{"��"});
    $base{$present,$hitpagel}="��pgl" if ($opts{"��"});
    
    $base{$future,$qal}="pgl" if ($opts{"��_����"});
    $base{$future,$qal}="pg�l" if ($opts{"��_�����"});
    $base{$future,$nifgal}="�pgl" if ($opts{"��"});
    $base{$future,$hifgil}="pg�l" if ($opts{"��"});
    $base{$future,$hufgal}="�pgl" if ($opts{"��"});
    $base{$future,$pigel}="pgl" if ($opts{"��"});
    $base{$future,$pugal}="p�gl" if ($opts{"��"});
    $base{$future,$hitpagel}="�pgl" if ($opts{"��"});
     
    $base{$imperative,$qal}="pgl" if ($opts{"��_����"});
    $base{$imperative,$qal}="pg�l" if ($opts{"��_�����"});
    # shouldn't be with yod? - ����� �� ����? 
    $base{$imperative,$nifgal}="��pgl" if ($opts{"��"});
    $base{$imperative,$hifgil}="�pg�l" if ($opts{"��"});
    $base{$imperative,$qal}="pg�l" if ($opts{"�����"});
    $base{$imperative,$pigel}="pgl" if ($opts{"��"});
    $base{$imperative,$hitpagel}="��pgl" if ($opts{"��"});
    
    $base{$shempoal,$qal}="pg�l�" if ($opts{"��_����"}||$opts{"��_�����"});
    $base{$shempoal,$nifgal}="��pgl��" if ($opts{"��"});
    $base{$shempoal,$hifgil}="�pgl�" if ($opts{"��"});
    $base{$shempoal,$pigel}="p�g�l" if ($opts{"��"});
    # todo: this does not always exist: "shiqur" 
    # quod-roots should not get yod:
    $base{$shempoal,$pigel}="pg�l" if ($opts{"��"} && length($g)>1);
    $base{$shempoal,$hitpagel}="��pgl��" if ($opts{"��"});
 
    $base{$maqor,$qal}="�pg�l" if ($opts{"��_����"}||$opts{"��_�����"});
    $base{$maqor,$qal}="�pgl" if ($opts{"����"}); # a very rare exception
    $base{$maqor,$nifgal}="���pgl" if ($opts{"��"});
    $base{$maqor,$hifgil}="��pg�l" if ($opts{"��"});
    $base{$maqor,$pigel}="�pgl" if ($opts{"��"});
    $base{$maqor,$hitpagel}="���pgl" if ($opts{"��"});
    
    foreach $tense (@all_tense) {
      foreach $binyan (@all_binyan) {
        $base = $base{$tense,$binyan};
        next unless defined($base); #no such conjugation..
        $naxe_base = binyan_root_clash($tense, $binyan, $p, $g, $l, $base);
        foreach $guf (legal_guf($tense)) {
          $naxe = guf_root_clash($tense, $guf, $p, $g, $l, $naxe_base);
          $conj_base = binyan_guf_clash($tense, $binyan, $guf, $naxe);
#          $asgn_base = assign_root($p, $g, $l, $conj_base);
#          $affx_base = add_guf_affix($tense, $guf, $asgn_base);
#          outword $affx_base;
          $affx_base = add_guf_affix($tense, $guf, $conj_base);
          $asgn_base = assign_root($p, $g, $l, $affx_base);
          outword $asgn_base;
        }
      }
    }
  } else {
    die "word '".$word."' was not specified as noun, adjective or verb.";
  }
  outword "-------"
}
