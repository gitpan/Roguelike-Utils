use strict;

package Games::Roguelike::Item;

use Games::Roguelike::Utils qw(:all);
use Games::Roguelike::Console;
use Games::Roguelike::Area;
use Carp qw(croak confess carp);

our $AUTOLOAD;

=head2 METHODS

=over 4

=cut 

=item new($container, %opts)

$container is usually an "area" or "mob" object.

At a minimum, it must support the additem and delitem methods and 
contain an {items} array which gets modified by "setcont"

The "new" method automatically calls additem on the container.

Options include:

	sym	: symbol this item is drawn with
	color	: color this item is drawn with
	x	: map location of item
	y 	: map location of item

Other options are saved in the hash as "user defined" options.

=cut

sub new {
        my $pkg = shift;

        my $cont = shift;

        croak("can't create item without container argument") 
		unless UNIVERSAL::can($cont, 'additem');
	
        my $self = {};

	$self->{sym}='$';			# default, just so there is one
	$self->{color}='bold yellow';		# default

	while( my ($k, $v) = splice(@_, 0, 2)) {
		$self->{$k} = $v;
	}
		
        bless $self, $pkg;

        $cont->additem($self);

        return $self;
}

=item x()

=item y()

Return the item's x/y members only if the item is in an area object,

Otherwise, they return the container's x and y members (this can be recursive).

=cut

sub x {
	my $self = shift;
	if (!$self->{inarea}) {
		return $self->{cont}->x;
	}
	return $self->{x};
}

sub y {
	my $self = shift;
	if (!$self->{inarea}) {
		return $self->{cont}->y;
	}
	return $self->{y};
}

=item setcont(newcont)

Sets the container for an item, returns 0 if it's already contained within that continer.  

Dies if the container has no {items} list (ie: can't contain things)

**Should only ever be called by the containers "additem" method.**

=cut

sub setcont {
	my $self = shift;
	my $cont = shift;

	confess("not an item") unless $self->isa('Games::Roguelike::Item');
	confess("not an container") unless ref($cont->{items}) && UNIVERSAL::can($cont, 'additem');

	if ($cont) {
		if (!defined($self->{cont}) || $cont != $self->{cont}) {
			$self->{in} = $cont->isa('Games::Roguelike::Area') ? 'area' : $cont->isa('Games::Roguelike::Mob') ? 'mob' : $cont->isa('Games::Roguelike::Item') ? 'item' : 'void';
			$self->{"in" . $self->{in}} = 1;

			die("item must be in a area, mob or another item as a container") 
				if $self->{invoid};

			$self->{cont}->delitem($self) if $self->{cont};
			push @{$cont->{items}}, $self;
			$self->{cont} = $cont;

			if ($self->{inarea}) {
				$self->{r} = $cont;
			} else {
				$self->{r} = $cont->{r};
			}

			return 1;
		}
		return 0;
	} else {
		return $self->{cont};
	}
}

# perl accessors are slow compared to just accessing the hash directly
# autoload is even slower
sub AUTOLOAD {
	my $self = shift;
	my $pkg = ref($self) or croak("$self is not an object");

	my $name = $AUTOLOAD;
	$name =~ s/.*://;   # strip fully-qualified portion
	$name =~ s/^set// if @_ && !exists $self->{$name};

	unless (exists $self->{$name}) {
	    croak "Can't access `$name' field in class $pkg";
	}

	if (@_) {
	    return $self->{$name} = $_[0];
	} else {
	    return $self->{$name};
	}
}

sub DESTROY {
}

=item additem (item)

Adds item to inventory.  Override this to make backpacks, etc.

Return value 0 		= can't add, too full/or not a backpack
Return value 1 		= add ok
Return value -1 	= move occured, but not added

Default implementation is to return "0", cannot add.

=cut

sub additem {
	my $self = shift;
	return 0;			# i'm not a backpack
}

=back

=head1 SEE ALSO

L<Games::Roguelike::Area>

=cut

1;
