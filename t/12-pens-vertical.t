#!/usr/bin/perl

use strict;

use Test::More tests => 4;

use Tickit::Test;

use Tickit::Widget::Static;
use Tickit::Widget::Tabbed;

my ( $term, $win ) = mk_term_and_window;

my $widget = Tickit::Widget::Tabbed->new( tab_position => "left" );

$widget->add_tab( Tickit::Widget::Static->new( text => "Widget" ), label => "tab" );
my $tab = $widget->add_tab( Tickit::Widget::Static->new( text => "Widget 2" ), label => "othertab" );

$widget->set_window( $win );

flush_tickit;

is_display( [ [TEXT("tab",fg=>14,bg=>4), TEXT(" >>>>>>",fg=>7,bg=>4), TEXT("Widget")],
              [TEXT("othertab  ",fg=>7,bg=>4)] ],
            'Display initially' );

$widget->pen_tabs->chattr(bg => 2);

flush_tickit;

is_display( [ [TEXT("tab",fg=>14,bg=>2), TEXT(" >>>>>>",fg=>7,bg=>2), TEXT("Widget")],
              [TEXT("othertab  ",fg=>7,bg=>2)] ],
            'Display after pen_tabs ->chattr' );

$widget->pen_active->chattr(b => 1);

flush_tickit;

is_display( [ [TEXT("tab",fg=>14,bg=>2,b=>1), TEXT(" >>>>>>",fg=>7,bg=>2), TEXT("Widget")],
              [TEXT("othertab  ",fg=>7,bg=>2)] ],
            'Display after pen_active ->chattr' );

$tab->pen->chattr(fg=>1);

flush_tickit;

is_display( [ [TEXT("tab",fg=>14,bg=>2,b=>1), TEXT(" >>>>>>",fg=>7,bg=>2), TEXT("Widget")],
              [TEXT("othertab",fg=>1,bg=>2), TEXT("  ",fg=>7,bg=>2)] ],
            'Display after tab pen ->chattr' );
