#!/usr/bin/perl

use strict;
use warnings;

use Tickit;

use Tickit::Widget::Static;
use Tickit::Widget::Tabbed;

use Getopt::Long;
GetOptions(
        'position|p=s' => \(my $position = "bottom"),
) or exit(1);

my $tabbed = Tickit::Widget::Tabbed->new( tab_position => $position );

foreach my $name (qw( First Second Third )) {
        $tabbed->add_tab( Tickit::Widget::Static->new( text => "Content for the $name Tab" ), label => $name );
}

my $tickit = Tickit->new();

$tickit->set_root_widget( $tabbed );

$tickit->run;
