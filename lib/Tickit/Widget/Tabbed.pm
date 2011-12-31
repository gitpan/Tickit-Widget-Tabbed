package Tickit::Widget::Tabbed;
# ABSTRACT: Basic tabbed window support
use strict;
use warnings;
use parent qw(Tickit::Widget);
BEGIN { Tickit::Widget->VERSION("0.12") }
use Carp;
use Tickit::Pen;
use Tickit::Utils qw(textwidth);
use List::Util qw(max);

our $VERSION = 0.003;

=head1 NAME

Tickit::Widget::Tabbed - provide tabbed window support

=head1 VERSION

version 0.002

=head1 SYNOPSIS

 use Tickit::Widget::Tabbed;
 my $tabbed = Tickit::Widget::Tabbed->new;
 $tabbed->add_tab(Tickit::Widget::Static->new(text => 'some text'), label => 'First tab');
 $tabbed->add_tab(Tickit::Widget::Static->new(text => 'some text'), label => 'Second tab');

=head1 DESCRIPTION

Provides a container that operates as a tabbed window.

Subclass of L<Tickit::ContainerWidget>.

=cut

=head1 METHODS

=cut

sub lines { 1 }

sub cols { shift->label_width + 1 }

sub TAB_CLASS { shift->{tab_class} || "Tickit::Widget::Tabbed::Tab" }

# Don't need to implement this as rendering is done by the child or the tab
# window using its expose event
sub render { }

=head2 new

Instantiate a new tabbed window.

Takes the following named parameters:

=over 4

=item * tab_position - (optional) location of the tabs, should be one of left, top, right, bottom.

=item * pen_tabs - (optional) C<Tickit::Pen> to use to render the tabs

=item * pen_active - (optional) C<Tickit::Pen> of additional attributes to use to render the active tab

=back

=cut

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new;
	$self->{tabs} = [];
	$self->{active_tab_index} = 0;
	$self->{pen_tabs}   = delete($args{pen_tabs})	|| Tickit::Pen->new( bg => 4, fg => 7 );
	$self->{pen_active} = delete($args{pen_active}) || Tickit::Pen->new( fg => 14 );
	$self->{tab_class}  = delete($args{tab_class});

	$_->add_on_changed($self, "tab") for $self->pen_tabs, $self->pen_active;

	$self->tab_position(delete($args{tab_position}) || 'top');

	return $self;
}

sub DESTROY {
	my $self = shift;

	defined $_ and $_->remove_on_changed($self) for $self->pen_tabs, $self->pen_active;
}

sub on_pen_changed {
	my $self = shift;
	my ( $pen, $id ) = @_;
	return $self->_tabs_changed if $id and $id eq "tab";
	return $self->SUPER::on_pen_changed( @_ );
}

sub label_width {
	my $self = shift;
	return 2 + max(0, map { textwidth($_->label) } @{$self->{tabs}});
}

=head2 child_window

Returns the child window.

=cut

# Positions for the four screen edges - these will return appropriate sizes
# for the tab and child subwindows
sub _window_position_left {
	my $self = shift;
	return 0, 0, $self->window->lines, $self->label_width,
	       0, $self->label_width, $self->window->lines, $self->window->cols - $self->label_width;
}

sub _window_position_right {
	my $self = shift;
	return 0, $self->window->cols - $self->label_width, $self->window->lines, $self->label_width,
	       0, 0, $self->window->lines, $self->window->cols - $self->label_width;
}

sub _window_position_top {
	my $self = shift;
	return 0, 0, 1, $self->window->cols,
	       1, 0, $self->window->lines - 1, $self->window->cols;
}

sub _window_position_bottom {
	my $self = shift;
	return $self->window->lines - 1, 0, 1, $self->window->cols,
	       0, 0, $self->window->lines - 1, $self->window->cols;
}

sub reshape {
	my $self = shift;
	my $window = $self->window or return;
	my $tab_position = $self->tab_position;
	my @positions = $self->${\"_window_position_$tab_position"}();
	if( $self->{tab_window} ) {
		$self->{tab_window}->change_geometry( @positions[0..3] );
	}
	else {
		$self->{tab_window} = $window->make_sub( @positions[0..3] );
		$self->{tab_window}->set_on_expose(sub { $self->_expose_tabs(@_) });
	}
	if( $self->{child_window} ) {
		$self->{child_window}->change_geometry( @positions[4..7] );
	}
	else {
		$self->{child_window} = $window->make_sub( @positions[4..7] );
		$self->tab->set_window($self->{child_window}) if $self->tab;
	}
}

sub child_window {
	my $self = shift;
	$self->reshape;
	return $self->{child_window};
}

sub window_lost {
	my $self = shift;
	$self->SUPER::window_lost(@_);
	$_->widget->set_window(undef) for @{$self->{tabs}};

	undef $self->{child_window};

	$self->{tab_window}->set_on_expose(undef);
	undef $self->{tab_window};
}

=head2 tab_position

Accessor for the tab position (top, left, right, bottom).

=cut

sub tab_position {
	my $self = shift;
	if(@_) {
		my $pos = shift;
		$self->{orientation} = ( $pos eq "top" or $pos eq "bottom" ) ? "horizontal" :
				       ( $pos eq "left" or $pos eq "right" ) ? "vertical" :
				       croak "Unrecognised value for ->tab_position: $pos";
		$self->{tab_position} = $pos;
		$self->tab->set_window(undef) if $self->tab;
		delete $self->{child_window};

		$self->reshape if $self->window;
		$self->redraw;
	}
	return $self->{tab_position};
}

=head2 pen_tabs

=head2 pen_active

Accessors for the rendering pens.

=cut

sub pen_tabs {
	my $self = shift;
	return $self->{pen_tabs};
}

sub pen_active {
	my $self = shift;
	return $self->{pen_active};
}

sub _tabs_changed {
	my $self = shift;
	$self->reshape if $self->window;
	$self->{tab_window}->expose if $self->{tab_window};
}

sub _expose_tabs {
	my $self = shift;
	my %args = @_;

	my $win = $self->{tab_window};

	my %attrs = $self->{pen_tabs}->getattrs;

	my $next_pos = 0;
	my $pos = $self->tab_position;
	my $idx = 0;
	foreach my $tab (@{$self->{tabs}}) {
		my $w = $self->label_width - length $tab->label;
		my $active = $tab->is_active;

# Select appropriate position for the labels
		if($self->{orientation} eq "horizontal") {
			$win->goto(0, $next_pos);
			$next_pos += length($tab->label) + 1;
		} else {
			$win->goto($next_pos, 0);
			++$next_pos;
		}

		my %tabattrs = ( %attrs,
			$tab->_has_pen ? $tab->pen->getattrs : (),
			$active ? $self->{pen_active}->getattrs : () );

# Show label in different style if this is the active tab
		if($pos eq 'left') {
			$win->print($tab->label, %tabattrs);
			$win->print($active ? (' ' . ('>' x ($w - 1))) : (' ' x $w), %attrs);
		} elsif($pos eq 'right') {
			$win->print($active ? (('<' x ($w - 1)) . ' ') : (' ' x $w), %attrs);
			$win->print($tab->label, %tabattrs);
		} else {
			$win->print($tab->label, %tabattrs);
			$win->print(' ', %attrs);
		}
	}

	if($self->{orientation} eq "horizontal") {
		$win->goto(0, $next_pos);
		$win->erasech($win->cols - $next_pos, undef, %attrs);
	} else {
		while($next_pos < $win->lines) {
			$win->goto($next_pos, 0);
			$win->erasech($self->label_width, undef, %attrs);
			++$next_pos;
		}
	}
}

=head2 active_tab_index

Returns the 0-based index of the currently-active tab.

=cut

sub active_tab_index { shift->{active_tab_index} }

=head2 active_tab

Returns the currently-active tab as a tab object. See below.

=cut

sub active_tab {
	my $self = shift;
	return $self->{tabs}->[$self->{active_tab_index}];
}

=head2 add_tab

Add a new tab to this tabbed widget. Returns an object representing the tab;
see L</METHODS ON TAB OBJECTS> below.

First parameter is the widget to use.

Remaining form a hash:

=over 4

=item label - label to show on the new tab

=back

=cut

sub add_tab {
	my $self = shift;
	my ($child, %opts) = @_;

	push @{$self->{tabs}}, my $tab = $self->TAB_CLASS->new( $self, widget => $child, %opts );
	$self->_tabs_changed;

	if(@{$self->{tabs}} == 1 and my $child_window = $self->child_window) {
		$tab->_activate;
		$child->set_window($child_window);
	}
	return $tab;
}

=head2 remove_tab

Remove tab given by 0-based index or tab object.

=cut

sub remove_tab {
	my $self = shift;
	my $del_index = $self->_tab2index( shift );

	splice @{$self->{tabs}}, $del_index, 1, ();
	$self->{active_tab_index}-- if $self->{active_tab_index} > $del_index;
	$self->_tabs_changed;
}

=head2 move_tab

Move tab given by 0-based index or tab object forward the given number of
positions.

=cut

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

	$self->{active_tab_index} += $delta if $self->{active_tab_index} == $old_index;
	$self->{active_tab_index}++ if $self->{active_tab_index} < $old_index and $self->{active_tab_index} >= $old_index + $delta;
	$self->{active_tab_index}-- if $self->{active_tab_index} > $old_index and $self->{active_tab_index} <= $old_index + $delta;

	$self->_tabs_changed;
}

=head2 tab

Returns the widget in the currently active tab.

=cut

sub tab { my $self = shift; $self->active_tab && $self->active_tab->widget }

sub child_resized {
	my $self = shift;
	$self->reshape;
}

=head2 activate_tab

Switch to the given tab; by 0-based index, or object.

=cut

sub _tab2index {
	my $self = shift;
	my ( $tab_or_index ) = @_;
	return $tab_or_index if !ref $tab_or_index;
	return ( grep { $tab_or_index == $self->{tabs}[$_] } 0 .. $#{ $self->{tabs} } )[0];
}

sub activate_tab {
	my $self = shift;
	my $new_index = $self->_tab2index( shift );

# Remember the child window if we have one
	my $win = $self->tab ? $self->tab->window : undef;
	$win ||= $self->child_window;
	$self->tab->set_window(undef) if $self->tab;

	return $self if $new_index == $self->{active_tab_index};

	$self->active_tab->_deactivate;

	$self->{active_tab_index} = $new_index;

	$self->_tabs_changed;

	if($self->tab) {
		$self->active_tab->_activate;
		$self->tab->set_window($win);
		$self->tab->redraw;
	}
	else {
		$win->clear;
	}

	return $self;
}

=head2 next_tab

Switch to the next tab.

=cut

sub next_tab {
	my $self = shift;
	$self->activate_tab($self->{active_tab_index} == $#{$self->{tabs}} ? 0 : $self->{active_tab_index} + 1);
}

=head2 prev_tab

Switch to the previous tab.

=cut

sub prev_tab {
	my $self = shift;
	$self->activate_tab($self->{active_tab_index} == 0 ? $#{$self->{tabs}} : $self->{active_tab_index} - 1);
}

sub on_key {
	my $self = shift;
	my ($type, $str, $key) = @_;
	if($self->{orientation} eq "horizontal") {
		if($type eq 'key' && $str eq 'Right') {
			$self->next_tab;
			return 1;
		} elsif($type eq 'key' && $str eq 'Left') {
			$self->prev_tab;
			return 1;
		}
	} else {
		if($type eq 'key' && $str eq 'Down') {
			$self->next_tab;
			return 1;
		} elsif($type eq 'key' && $str eq 'Up') {
			$self->prev_tab;
			return 1;
		}
	}
	if($type eq 'key' && $str eq 'C-PageUp') {
		$self->prev_tab;
		return 1;
	}
	if($type eq 'key' && $str eq 'C-PageDown') {
		$self->next_tab;
		return 1;
	}
	if($type eq 'key' && $str =~ m/^M-(\d)$/ ) {
		my $index = $1 - 1;
		$self->activate_tab( $index ) if $index <= $#{$self->{tabs}};
		return 1;
	}
	if($type eq 'key' && $str eq 'Tab') {
		my $target = $self->tab;
		unless($target) {
			$target = $self;
			$target = $target->parent while $target->parent;
		}
		$target->window->focus(0,0) if $target->window;
		$target->children_changed if $target->can('children_changed');
		return 1;
	}
	return 0;
}

package Tickit::Widget::Tabbed::Tab;
use Scalar::Util qw( weaken );

=head1 METHODS ON TAB OBJECTS

The following methods may be called on the objects returned by C<add_tab> or
C<active_tab>.

=cut

sub new {
	my $class = shift;
	my ( $tabbed, %args ) = @_;
	my $self = bless {
		tabbed => $tabbed,
		widget => $args{widget},
		label  => $args{label},
		active => 0,
	}, $class;
	weaken( $self->{tabbed} );
	return $self;
}

=head2 index

Returns the 0-based index of this tab

=cut

sub index {
	my $self = shift;
	return $self->{tabbed}->_tab2index( $self );
}

=head2 widget

Returns the C<Tickit::Widget> contained by this tab

=cut

sub widget { shift->{widget} }

=head2 label

Returns the current label text

=cut

sub label { shift->{label} }

=head2 set_label

Set new label text for the tab

=cut

sub set_label {
	my $self = shift;
	( $self->{label} ) = @_;
	$self->{tabbed}->_tabs_changed if $self->{tabbed};
}

=head2 is_active

Returns true if this tab is the currently active one

=cut

sub is_active {
	my $self = shift;
	return $self->{tabbed}->active_tab == $self;
}

sub _activate {
	my $self = shift;
	$self->{on_activated}->( $self ) if $self->{on_activated};
}

sub _deactivate {
	my $self = shift;
	$self->{on_deactivated}->( $self ) if $self->{on_deactivated};
}

=head2 set_on_activated

Set a callback to invoke when the tab is activated

=cut

sub set_on_activated
{
	my $self = shift;
	( $self->{on_activated} ) = @_;
}

=head2 set_on_deactivated

Set a callback to invoke when the tab is deactivated

=cut

sub set_on_deactivated
{
	my $self = shift;
	( $self->{on_deactivated} ) = @_;
}

=head2 pen

Returns the C<Tickit::Pen> used to draw the label

=cut

sub _has_pen { defined shift->{pen} }

sub pen {
	my $self = shift;
	return $self->{pen} ||= do {
		my $pen = Tickit::Pen->new;
		$pen->add_on_changed( $self );
		$pen
	};
}

sub on_pen_changed {
	my $self = shift;
	$self->{tabbed}->_tabs_changed if $self->{tabbed};
}

1;

__END__

=head1 CUSTOM TAB CLASS

Rather than use the default built-in object class for tab objects, a
C<Tickit::Widget::Tabbed> or subclass thereof can return objects in another
class instead. This is most useful for subclasses of the tabbed widget itself.

To perform this, create a subclass of C<Tickit::Widget::Tabbed::Tab> with a
constructor having the following behaviour:

 sub new
 {
	 my $class = shift;
	 my ( $tabbed, %args ) = @_;

	 ...

	 my $self = $class->SUPER::new( $tabbed, %args );

	 ...

	 return $self;
 }

Arrange for this class to be used by the tabbed widget either by passing its
name as a constructor argument called C<tab_class>, or by overriding a method
called C<TAB_CLASS>.

 my $tabbed = Tickit::Widget::Tabbed->new(
	 tab_class => "Tab::Class::Name"
 );

or

 use constant TAB_CLASS => "Tab::Class::Name";

=cut

=head1 SEE ALSO

=over 4

=item * L<Tickit::Widget::Table>

=item * L<Tickit::Widget::HBox>

=item * L<Tickit::Widget::VBox>

=item * L<Tickit::Widget::Tree>

=item * L<Tickit::Window>

=back

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2011. Licensed under the same terms as Perl itself.
