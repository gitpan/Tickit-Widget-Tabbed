package Tickit::Widget::Tabbed::Ribbon;

use strict;
use warnings;

use base qw( Tickit::Widget );

our $VERSION = '0.008';

use Scalar::Util qw( weaken );
use Tickit::Utils qw( textwidth );

use Carp;

=head1 NAME

C<Tickit::Widget::Tabbed::Ribbon> - base class for C<Tickit::Widget::Tabbed>
control ribbon

=head1 DESCRIPTION

This class contains the default implementation for the control ribbon used by
L<Tickit::Widget::Tabbed>, and also acts as a base class to assist in the
creation of a custom ribbon. Details of this class and its operation are
useful to know when implenting a custom control ribbon.

It is not necessary to consider this class if simply using the
C<Tickit::Widget::Tabbed> with its default control ribbon.

=head1 CUSTOM RIBBON CLASS

To perform create a custom ribbon class, create a subclass of
C<Tickit::Widget::Tabbed::Ribbon> with a constructor having the following
behaviour:

 package Custom::Ribbon::Class;
 use base qw( Tickit::Widget::Tabbed::Ribbon );

 sub new_for_orientation
 {
	 my $class = shift;
	 my ( $orientation, %args ) = @_;

	 ...

	 return $self;
 }

Alternatively if this is not done, then one of two subclasses will be used for
the constructor, by appending C<::horizontal> or C<::vertical> to the class
name. In this case, the custom class should provide these as well.

 package Custom::Ribbon::Class;
 use base qw( Tickit::Widget::Tabbed::Ribbon );

 package Custom::Ribbon::Class::horizontal;
 use base qw( Custom::Ribbon::Class );

 ...

 package Custom::Ribbon::Class::vertical;
 use base qw( Custom::Ribbon::Class );

 ...

Arrange for this class to be used by the tabbed widget either by passing its
name as a constructor argument called C<ribbon_class>, or by overriding a
method called C<RIBBON_CLASS>.

 my $tabbed = Tickit::Widget::Tabbed->new(
	 ribbon_class => "Ribbon::Class::Name"
 );

or

 use constant RIBBON_CLASS => "Ribbon::Class::Name";

=cut

=head1 METHODS

=cut

use constant CLEAR_BEFORE_RENDER => 0;

=head2 $pen = $ribbon->active_pen

Returns the L<Tickit::Pen> object used for the active tab

=cut

use Tickit::WidgetRole::Penable
	name => 'active', default => { fg => 14 };

use Tickit::WidgetRole::Penable
	name => 'more', default => { fg => 'cyan' };

sub new_for_orientation {
        my $class = shift;
        my ( $orientation, @args ) = @_;

        return ${\"${class}::${orientation}"}->new( @args );
}

sub new {
	my $class = shift;
	my %args = @_;

	foreach my $method (qw( scroll_to_visible on_key on_mouse )) {
		$class->can( $method ) or
			croak "$class cannot ->$method - do you subclass and implement it?";
	}

	# TODO: Move widget default pen into the Penable role so this can be
	# neater
	exists $args{bg} or $args{bg} = 4;
	exists $args{fg} or $args{fg} = 7;
	
	my $self = $class->SUPER::new( %args );

	$self->_init_active_pen;
	$self->_init_more_pen;

	$self->set_more_markers( "<..", "..>" );

	$self->{tabs} = [];
	push @{$self->{tabs}}, @{$args{tabs}} if $args{tabs};

	$self->{scroll_offset} = 0;
	$self->{active_tab_index} = $args{active_tab_index} || 0;

	weaken( $self->{tabbed} = $args{tabbed} );

	$self->scroll_to_visible( $self->{active_tab_index} );

	return $self;
}

=head2 @tabs = $ribbon->tabs

=head2 $count = $ribbon->tabs

Returns a list of the contained L<Tickit::Widget::Tabbed> tab objects in list
context, or the count of them in scalar context.

=cut

sub tabs {
	my $self = shift;
	return @{$self->{tabs}};
}

sub _tab2index {
	my $self = shift;
	my ( $tab_or_index ) = @_;
	if( !ref $tab_or_index ) {
		croak "Invalid tab index" if $tab_or_index < 0 or $tab_or_index >= @{ $self->{tabs} };
		return $tab_or_index;
	}
	return ( grep { $tab_or_index == $self->{tabs}[$_] } 0 .. $#{ $self->{tabs} } )[0];
}

=head2 $index = $ribbon->active_tab_index

Returns the index of the currently-active tab

=cut

sub active_tab_index {
	my $self = shift;
	return $self->{active_tab_index};
}

=head2 $tab = $ribbon->active_tab

Returns the currently-active tab as a C<Tickit::Widget::Tabbed> tab object.

=cut

sub active_tab {
	my $self = shift;
	return $self->{tabs}->[$self->{active_tab_index}];
}

sub append_tab {
	my $self = shift;
	my ( $tab ) = @_;

	push @{$self->{tabs}}, $tab;

	$self->{tabbed}->_tabs_changed;
	$self->scroll_to_visible( undef );
}

sub remove_tab {
	my $self = shift;
	my $del_index = $self->_tab2index( shift );

	my $tabs = $self->{tabs};

	splice @$tabs, $del_index, 1, ();
	if( $self->{active_tab_index} > $del_index ) {
		$self->{active_tab_index}--;
	}
	elsif( $self->{active_tab_index} == $del_index ) {
		$self->{active_tab_index}-- if $del_index == @$tabs;
		if( $self->active_tab ) {
			$self->active_tab->_activate;
		}
		else {
			$self->{tabbed}->window->clear;
		}
	}

	$self->{tabbed}->_tabs_changed;
	$self->scroll_to_visible( undef );
}

sub move_tab {
	my $self = shift;
	my $old_index = $self->_tab2index( shift );
	my $delta = shift;

	my $tabs = $self->{tabs};

	if( $delta < 0 ) {
		$delta = -$old_index if $delta < -$old_index;
	}
	elsif( $delta > 0 ) {
		my $spare = $#$tabs - $old_index;
		$delta = $spare if $delta > $spare;
	}
	else {
		# delta == 0
		return;
	}

	splice @$tabs, $old_index + $delta, 0, ( splice @$tabs, $old_index, 1, () );

	# Adjust the active_tab_index to cope with tab move
	$self->{active_tab_index} += $delta if $self->{active_tab_index} == $old_index;
	$self->{active_tab_index}++ if $self->{active_tab_index} < $old_index and $self->{active_tab_index} >= $old_index + $delta;
	$self->{active_tab_index}-- if $self->{active_tab_index} > $old_index and $self->{active_tab_index} <= $old_index + $delta;

	$self->redraw;
}

sub activate_tab {
	my $self = shift;
	my $new_index = $self->_tab2index( shift );

	return if $new_index == $self->{active_tab_index};

	if(my $old_widget = $self->active_tab->widget) {
		$self->active_tab->_deactivate;
	}

	$self->{active_tab_index} = $new_index;

	$self->scroll_to_visible( $self->{active_tab_index} );

	$self->redraw;

	if(my $tab = $self->active_tab) {
		$tab->_activate;
	}
	else {
		$self->window->clear;
	}

	return $self;
}

sub next_tab {
	my $self = shift;
	$self->activate_tab( ( $self->active_tab_index + 1 ) % $self->tabs );
}

sub prev_tab {
	my $self = shift;
	$self->activate_tab( ( $self->active_tab_index - 1 ) % $self->tabs );
}

sub on_pen_changed {
	my $self = shift;
	my ( $pen, $id ) = @_;
	$self->redraw;
	return $self->SUPER::on_pen_changed( @_ );
}

sub set_more_markers {
	my $self = shift;
	my ( $prev_more, $next_more ) = @_;

	$self->{prev_more} = [ $prev_more, textwidth $prev_more ];
	$self->{next_more} = [ $next_more, textwidth $next_more ];
}

sub on_key { 0 }

sub on_mouse { 0 }

package Tickit::Widget::Tabbed::Ribbon::horizontal;
use base qw( Tickit::Widget::Tabbed::Ribbon );
use constant orientation => "horizontal";

use List::Util qw( sum );

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new( %args );
	$self->{active_marker} = $args{active_marker} || [ "[", "]" ];
	return $self;
}

sub lines { 1 }
sub cols {
	my $self = shift;
	return sum(map { $_->label_width + 1 } $self->tabs);
}

sub reshape {
	my $self = shift;

	my $win = $self->window or return;

	$self->scroll_to_visible( undef );

	my $prev_more = $self->{prev_more};
	if( $prev_more->[2] ) {
		$prev_more->[2]->change_geometry(
			0, 0, 1, $prev_more->[1],
		);
	}

	my $next_more = $self->{next_more};
	if( $next_more->[2] ) {
		$next_more->[2]->change_geometry(
			0, $win->cols - $next_more->[1], 1, $next_more->[1],
		);
	}
}

sub render {
	my $self = shift;
	my %args = @_;

	my $win = $self->window or return;
	my $rect = $args{rect};

	$rect->top == 0 or return;
	$rect->bottom == 1 or return;

	my $next_col = -$self->{scroll_offset};

	my $prev_active;
	foreach my $tab ($self->tabs) {
		my $active = $tab->is_active;

# Select appropriate position for the labels
		return if $next_col >= $rect->right;
		my $this_col = $next_col;

		$next_col += $tab->label_width + 1;
		next unless $next_col >= $rect->left;

		# Only need to goto the first time
		$win->goto(0, $this_col) if $this_col <= 0;

# Show label in different style if this is the active tab
		my %tabattrs = (
			$tab->_has_pen ? $tab->pen->getattrs : (),
			$active ? $self->active_pen->getattrs : () );

		$win->print($active      ? $self->{active_marker}[0] :
			    $prev_active ? $self->{active_marker}[1] :
			                   ' ');
		$win->print($tab->label, %tabattrs);

		$prev_active = $active;
	}

	if($prev_active) {
		$win->print($self->{active_marker}[1]);
		$next_col++;
	}

	$win->goto(0, $next_col) if $next_col == 0;
	$win->erasech($win->cols - $next_col);
}

sub _col2tab {
	my $self = shift;
	my ( $col ) = @_;

	$col += $self->{scroll_offset};
	$col--;
	return if $col < 0;

	foreach my $tab ( $self->tabs ) {
		if( $col < $tab->label_width ) {
			return $tab, $col if wantarray;
			return $tab;
		}
		$col -= $tab->label_width;
		return if $col == 0;
		$col--;
	}
	return;
}

sub scroll_to_visible {
	my $self = shift;
	my ( $target_idx ) = @_;

	my $win = $self->window or return;
	my $cols = $win->cols;

	my $prev_more = $self->{prev_more} or return;
	my $next_more = $self->{next_more} or return;

	my @tabs = $self->tabs;
	my $halfwidth = int( $cols / 2 );

	my $ofs = $self->{scroll_offset};
	my $want_prev_more = defined $prev_more->[2];
	my $want_next_more = defined $next_more->[2];

	{
		my $col = -$ofs;
		$col++; # initial space

		my $start_of_idx;
		my $end_of_idx;

		my $i = 0;
		if( defined $target_idx ) {
			for( ; $i < $target_idx; $i++ ) {
				$col += $tabs[$i]->label_width + 1;
			}

			$start_of_idx = $col;
			$col += $tabs[$i++]->label_width;
			$end_of_idx = $col;
			$col++;
		}

		for( ; $i < @tabs; $i++ ) {
			$col += $tabs[$i]->label_width + 1;
		}
		$col--;

		$want_prev_more = ( $ofs > 0 );
		$want_next_more = ( $col > $cols );

		my $left_margin  = $want_prev_more ? $prev_more->[1]
						   : 0;
		my $right_margin = $want_next_more ? $cols - $next_more->[1]
						   : $cols;

		if( defined $start_of_idx and $start_of_idx < $left_margin ) {
			$ofs -= $halfwidth;
			$ofs = 0 if $ofs < 0;
			redo;
		}

		if( defined $end_of_idx and $end_of_idx >= $right_margin ) {
			$ofs += $halfwidth;
			redo;
		}
	}

	$self->{scroll_offset} = $ofs;

	if( $want_prev_more and !$prev_more->[2] ) {
		my $w = $win->make_float(
			0, 0, 1, $prev_more->[1],
		);
		$prev_more->[2] = $w;
		$w->set_pen( $self->more_pen );
		$w->set_on_expose( sub {
			my $win = shift;
			$win->goto( 0, 0 );
			$win->print( $prev_more->[0] );
			$win->restore;
		} );
		$w->set_on_mouse( sub {
			my $win = shift;
			my ( $ev, $button ) = @_;
			$self->_scroll_left if $ev eq "press" && $button == 1;
			return 1;
		} );
	}
	elsif( !$want_prev_more and $prev_more->[2] ) {
		$prev_more->[2]->hide;
		undef $prev_more->[2];
	}

	if( $want_next_more and !$next_more->[2] ) {
		my $w = $win->make_float(
			0, $win->cols - $next_more->[1], 1, $next_more->[1],
		);
		$next_more->[2] = $w;
		$w->set_pen( $self->more_pen );
		$w->set_on_expose( sub {
			my $win = shift;
			$win->goto( 0, 0 );
			$win->print( $next_more->[0] );
			$win->restore;
		} );
		$w->set_on_mouse( sub {
			my $win = shift;
			my ( $ev, $button ) = @_;
			$self->_scroll_right if $ev eq "press" && $button == 1;
			return 1;
		} );
	}
	elsif( !$want_next_more and $next_more->[2] ) {
		$next_more->[2]->hide;
		undef $next_more->[2];
	}
}

sub _scroll_left {
	my $self = shift;

	my $win = $self->window or return;

	$self->{scroll_offset} -= int( $win->cols / 2 );
	$self->{scroll_offset} = 0 if $self->{scroll_offset} < 0;
	$self->scroll_to_visible( undef );
	$self->redraw;
}

sub _scroll_right {
	my $self = shift;

	my $win = $self->window or return;

	$self->{scroll_offset} += int( $win->cols / 2 );
	$self->scroll_to_visible( undef );
	$self->redraw;
}

sub on_key {
	my $self = shift;
	my ($type, $str) = @_;

	if($type eq 'key' && $str eq 'Right') {
		$self->next_tab;
		return 1;
	} elsif($type eq 'key' && $str eq 'Left') {
		$self->prev_tab;
		return 1;
	}
}

sub on_mouse {
	my $self = shift;
	my ( $ev, $button, $line, $col ) = @_;

	return 0 unless $line == 0;
	return 0 unless my ( $tab, $tab_col ) = $self->_col2tab( $col );

	return $tab->on_mouse( $ev, $button, 0, $tab_col );
}

package Tickit::Widget::Tabbed::Ribbon::vertical;
use base qw( Tickit::Widget::Tabbed::Ribbon );
use constant orientation => "vertical";

use List::Util qw( max );

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new( %args );
	$self->{tab_position} = $args{tab_position};
	return $self;
}

sub lines {
	my $self = shift;
	return scalar $self->tabs;
}
sub cols {
	my $self = shift;
	return 2 + max(0, map { $_->label_width } $self->tabs);
}

sub reshape {
	my $self = shift;

	my $win = $self->window or return;

	$self->scroll_to_visible( undef );

	my $prev_more = $self->{prev_more};
	if( $prev_more->[2] ) {
		$prev_more->[2]->change_geometry(
			0, 0, 1, $win->cols,
		);
	}

	my $next_more = $self->{next_more};
	if( $next_more->[2] ) {
		$next_more->[2]->change_geometry(
			$win->lines - 1, $win->cols, 1, $win->cols,
		);
	}
}

sub render {
	my $self = shift;
	my %args = @_;

	my $win = $self->window or return;
	my $rect = $args{rect};

	my $pos = $self->{tab_position};

	my $next_line = -$self->{scroll_offset};
	foreach my $tab ($self->tabs) {
		my $active = $tab->is_active;

		my $this_line = $next_line;
		$next_line++;

# Select appropriate position for the labels
		next if $this_line < $rect->top;
		return if $this_line >= $rect->bottom;
		$win->goto($this_line, 0);

		my %tabattrs = (
			$tab->_has_pen ? $tab->pen->getattrs : (),
			$active ? $self->active_pen->getattrs : () );

		my $spare = $win->cols - $tab->label_width;
# Show label in different style if this is the active tab
		if($pos eq 'left') {
			$win->print($tab->label, %tabattrs);
			$win->print($active ? (' ' . ('>' x ($spare - 1))) : (' ' x $spare));
		} elsif($pos eq 'right') {
			$win->print($active ? (('<' x ($spare - 1)) . ' ') : (' ' x $spare));
			$win->print($tab->label, %tabattrs);
		}
	}

	while($next_line < $win->lines) {
		$win->goto($next_line, 0);
		$win->erasech($win->cols);
		++$next_line;
	}
}

sub scroll_to_visible {
	my $self = shift;
	my ( $idx ) = @_;

	defined $idx or return;

	my $win = $self->window or return;
	my $lines = $win->lines;

	my $halfheight = int( $lines / 2 );

	my $ofs = $self->{scroll_offset};

	{
		my $line = -$ofs;
		$line += $idx;

		if( $line < 0 ) {
			$ofs -= $halfheight;
			$ofs = 0 if $ofs < 0;
			redo;
		}

		if( $line >= $lines ) {
			$ofs += $halfheight;
			redo;
		}
	}

	$self->{scroll_offset} = $ofs;
}

sub _showhide_more_markers {
}

sub on_key {
	my $self = shift;
	my ($type, $str) = @_;

	if($type eq 'key' && $str eq 'Down') {
		$self->next_tab;
		return 1;
	} elsif($type eq 'key' && $str eq 'Up') {
		$self->prev_tab;
		return 1;
	}
}

sub on_mouse {
	my $self = shift;
	my ( $ev, $button, $line, $col ) = @_;

	$line += $self->{scroll_offset};

	my @tabs = $self->tabs;
	return 0 unless $line < @tabs;

	return $tabs[$line]->on_mouse( $ev, $button, 0, $col );
}

1;

=head1 SUBCLASS METHODS

The subclass will need to provide implementations of the following methods.

=cut

=head2 $ribbon->render( %args )

=head2 $lines = $ribbon->lines

=head2 $cols = $ribbon->cols

As per the L<Tickit::Widget> methods.

=head2 $handled = $ribbon->on_key( $type, $str, $key )

=head2 $handled = $ribbon->on_mouse( $ev, $button, $line, $col )

As per the L<Tickit::Widget> methods. Optional. If not supplied then the
ribbon will not respond to keyboard or mouse events.

=head2 $ribbon->scroll_to_visible( $index )

Requests that a scrollable control ribbon scrolls itself so that the given
C<$index> tab is visible.

=cut

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut
