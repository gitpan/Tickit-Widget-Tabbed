#!/usr/bin/perl

use strict;

use Test::More tests => 2;

use Tickit::Test;

use Tickit::Widget::Static;
use Tickit::Widget::Tabbed;

my ( $term, $win ) = mk_term_and_window;

my $widget = Tickit::Widget::Tabbed->new( tab_position => "left" );

my $tab = $widget->add_tab( Tickit::Widget::Static->new( text => "Widget" ), label => "tab" );

$widget->set_window( $win );

flush_tickit;
$term->methodlog;

is_display( [ [TEXT("tab",fg=>14,bg=>4), TEXT(" >",fg=>7,bg=>4), TEXT("Widget")] ],
            'Display initially' );

$tab->set_label( "newlabel" );

flush_tickit;

is_display( [ [TEXT("newlabel",fg=>14,bg=>4), TEXT(" >",fg=>7,bg=>4), TEXT("Widget")] ],
            'Display after ->set_label' );
