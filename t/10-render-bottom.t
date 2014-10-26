#!/usr/bin/perl

use strict;

use Test::More tests => 8;

use Tickit::Test;

use Tickit::Widget::Static;
use Tickit::Widget::Tabbed;

my $win = mk_window;

my @statics = map { Tickit::Widget::Static->new( text => "Widget $_" ) } 0 .. 2;

my $widget = Tickit::Widget::Tabbed->new( tab_position => "bottom" );

ok( defined $widget, 'defined $widget' );

$widget->add_tab( $statics[$_], label => "tab$_" ) for 0 .. $#statics;

$widget->set_window( $win );

ok( defined $statics[0]->window, '$static has window after ->set_window $win' );

flush_tickit;

is_termlog( [ GOTO(0,0),
              SETPEN,
              PRINT("Widget 0"),
              SETBG(undef),
              ERASECH(72),
              ( map { GOTO($_,0), SETBG(undef), ERASECH(80) } 1 .. 23 ),

              GOTO(24,0),
              SETPEN(fg => 7,bg => 4),
              PRINT("["),
              SETPEN(fg => 14,bg => 4),
              PRINT("tab0"),
              SETPEN(fg => 7,bg => 4),
              PRINT("]"),
              SETPEN(fg => 7,bg => 4),
              PRINT("tab1"),
              SETPEN(fg => 7,bg => 4),
              PRINT(" "),
              SETPEN(fg => 7,bg => 4),
              PRINT("tab2"),
              SETBG(4),
              ERASECH(65) ],
            'Termlog initially' );

is_display( [ [TEXT("Widget 0")],
              BLANKLINES(23),
              [TEXT("[",fg=>7,bg=>4),
               TEXT("tab0",fg=>14,bg=>4),
               TEXT("]tab1 tab2 ",fg=>7,bg=>4),
               TEXT("",bg=>4)] ],
            'Display initially' );

$widget->next_tab;

flush_tickit;

is_termlog( [ GOTO(24,0),
              SETPEN(fg => 7,bg => 4),
              PRINT(" "),
              SETPEN(fg => 7,bg => 4),
              PRINT("tab0"),
              SETPEN(fg => 7,bg => 4),
              PRINT("["),
              SETPEN(fg => 14,bg => 4),
              PRINT("tab1"),
              SETPEN(fg => 7,bg => 4),
              PRINT("]"),
              SETPEN(fg => 7,bg => 4),
              PRINT("tab2"),
              SETBG(4),
              ERASECH(65),

              GOTO(0,0),
              SETPEN,
              PRINT("Widget 1"),
              SETBG(undef),
              ERASECH(72),
              ( map { GOTO($_,0), SETBG(undef), ERASECH(80) } 1 .. 23 ) ],

              'Termlog after ->next_tab' );

is_display( [ [TEXT("Widget 1")],
              BLANKLINES(23),
              [TEXT(" tab0[",fg=>7,bg=>4),
               TEXT("tab1",fg=>14,bg=>4),
               TEXT("]tab2 ",fg=>7,bg=>4),
               TEXT("",bg=>4)] ],
            'Display after ->next_tab' );

$widget->add_tab( Tickit::Widget::Static->new( text => "Another static" ), label => "newtab" );

flush_tickit;

is_termlog( [ GOTO(24,0),
              SETPEN(fg => 7,bg => 4),
              PRINT(" "),
              SETPEN(fg => 7,bg => 4),
              PRINT("tab0"),
              SETPEN(fg => 7,bg => 4),
              PRINT("["),
              SETPEN(fg => 14,bg => 4),
              PRINT("tab1"),
              SETPEN(fg => 7,bg => 4),
              PRINT("]"),
              SETPEN(fg => 7,bg => 4),
              PRINT("tab2"),
              SETPEN(fg => 7,bg => 4),
              PRINT(" "),
              SETPEN(fg => 7,bg => 4),
              PRINT("newtab"),
              SETBG(4),
              ERASECH(58) ],
            'Termlog after ->add_tab' );

is_display( [ [TEXT("Widget 1")],
              BLANKLINES(23),
              [TEXT(" tab0[",fg=>7,bg=>4),
               TEXT("tab1",fg=>14,bg=>4),
               TEXT("]tab2 newtab ",fg=>7,bg=>4),
               TEXT("",bg=>4)] ],
            'Display after ->add_tab' );
