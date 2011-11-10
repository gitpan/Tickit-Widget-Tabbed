#!/usr/bin/perl

use strict;

use Test::More tests => 4;

use Tickit::Test;

use Tickit::Widget::Static;
use Tickit::Widget::Tabbed;

my ( $term, $win ) = mk_term_and_window;

my $widget = Tickit::Widget::Tabbed->new( tab_position => "left" );

$widget->add_tab( Tickit::Widget::Static->new( text => "Widget $_" ), label => "tab$_" ) for 1 .. 3;

$widget->set_window( $win );

flush_tickit;

is_display( [ [TEXT("tab1",fg=>14,bg=>4), TEXT(" >",fg=>7,bg=>4), TEXT("Widget 1")],
              [TEXT("tab2  ",fg=>7,bg=>4)],
              [TEXT("tab3  ",fg=>7,bg=>4)] ],
            'Display initially' );

presskey( key => "Down" );

flush_tickit;

is_display( [ [TEXT("tab1  ",fg=>7,bg=>4), TEXT("Widget 2")],
              [TEXT("tab2",fg=>14,bg=>4), TEXT(" >",fg=>7,bg=>4)],
              [TEXT("tab3  ",fg=>7,bg=>4)] ],
            'Display after Down key' );

presskey( key => "C-PageDown" );

flush_tickit;

is_display( [ [TEXT("tab1  ",fg=>7,bg=>4), TEXT("Widget 3")],
              [TEXT("tab2  ",fg=>7,bg=>4)],
              [TEXT("tab3",fg=>14,bg=>4), TEXT(" >",fg=>7,bg=>4)] ],
            'Display after C-PageDown key' );

presskey( key => "M-1" );

flush_tickit;

is_display( [ [TEXT("tab1",fg=>14,bg=>4), TEXT(" >",fg=>7,bg=>4), TEXT("Widget 1")],
              [TEXT("tab2  ",fg=>7,bg=>4)],
              [TEXT("tab3  ",fg=>7,bg=>4)] ],
            'Display after M-1 key' );
