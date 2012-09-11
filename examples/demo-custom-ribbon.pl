#!/usr/bin/perl

use strict;
use warnings;

use Tickit;

use Tickit::Widget::Static;
use Tickit::Widget::Tabbed;

my $tabbed = Tickit::Widget::Tabbed->new(
   tab_position => "bottom",
   ribbon_class => "CustomRibbon",
);
$tabbed->pen_active->chattrs( { b => 1, u => 1 } );

my $counter = 1;
sub add_tab
{
        $tabbed->add_tab(
                Tickit::Widget::Static->new( text => "Content for tab $counter" ),
                label => "tab$counter",
        );
        $counter++
}

add_tab for 1 .. 3;

my $tickit = Tickit->new();

$tickit->set_root_widget( $tabbed );

$tickit->bind_key(
        'C-a' => \&add_tab
);
$tickit->bind_key(
        'C-d' => sub {
                $tabbed->remove_tab( $tabbed->active_tab );
        },
);

$tickit->run;

package CustomRibbon;
use base qw( Tickit::Widget::Tabbed::Ribbon );

package CustomRibbon::horizontal;
use base qw( CustomRibbon );

use Tickit::Utils qw( textwidth );

sub lines { 1 }
sub cols  { 1 }

sub render
{
        my $self = shift;
        my %args = @_;

        my $win = $self->window or return;

        my @tabs = $self->tabs;

        my $col = 0;
        my $printed;

        # TODO: consider whether $win->print should return width?

        $win->goto( 0, $col );
        $win->print( $printed = sprintf "[%d tabs]: ", scalar @tabs );
        $col += textwidth $printed;

        my $active = $self->active_tab;
        $win->print( $printed = $active->label, $self->active_pen );
        $col += textwidth $printed;

        $win->print( $printed = " [also:" );
        $col += textwidth $printed;

        foreach my $tab ( @tabs ) {
                $win->erasech( 1, 1 ); $col += 1;
                if( $tab == $active ) {
                        $win->print( $printed = "x" x textwidth( $tab->label ), fg => 8 );
                }
                else {
                        $win->print( $printed = $tab->label );
                }
                $col += textwidth $printed;
        }

        $win->print( "]" );
        $col += 1;

        if( ( my $spare = $win->cols - $col ) > 0 ) {
                $win->erasech( $spare );
        }
}

sub scroll_to_visible { }
