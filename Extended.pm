package IEEE754;

use strict;
use warnings;

# if invoked from the command line, call run() with command-line input

__PACKAGE__->run( @ARGV ) unless caller();

# construct the object and print its details
sub run {
    my $class = shift;
    die "usage: $0 number [k] [n]\n" unless @_;
    my $x = IEEE754->new(@_);
    print $x->details;
}

# construct a new IEEE754 float object; assume the exponent gets
# 8 bits and the fraction gets 23 bits unless otherwise specified
sub new {
    my $class = shift;
    (my $data = $_[0]) =~ y/0-9a-fA-FxX//cd;
    $data = eval $data;  # I don't like this
    my $k = $_[1] || 8;  # defaults to 8-bit exponent
    my $n = $_[2] || 23; # defaults to 23-bit fraction
    return bless [$data, $k, $n], $class;
}

sub data { return $_[0][0]; }
sub k    { return $_[0][1]; }
sub n    { return $_[0][2]; }
sub bias { return 2 ** ($_[0]->k - 1) - 1; }

sub sign_bit {
    my ($data, $k, $n) = @{ $_[0] };
    return ($data >> ($k + $n)) & 1;
}

sub sign {
    return $_[0]->sign_bit() == 0 ? 1 : -1;
}

sub exp {
    my ($data, $k, $n) = @{ $_[0] };
    my $mask = (1 << $k) - 1;
    return ($data >> $n) & $mask;
}

# This function returns a list containing the bits of a binary representation
# of the fraction
sub frac_bits {
    my ($data, $k, $n) = @{ $_[0] };
    return map { ($data >> $_) & 1 } reverse 0 .. $n-1;
}

sub frac {
    my ($power,$sum) = (1,0);
    for ($_[0]->frac_bits) {
        $power *= 0.5;
        $sum += $power * $_;
    }
    return $sum;
}

# A number is "special" if its exponent bits are all 1.
sub is_special {
    return ($_[0]->exp == (1 << $_[0]->k) - 1) ? 1 : 0;
}

# A number is infinity if it's special and its fraction bits are all 0
+.
sub is_inf {
    return $_[0]->is_special && ($_[0]->frac == 0);
}

# A number is NaN if it's special and its fraction bits are not all 0.
sub is_NaN {
    return $_[0]->is_special && ($_[0]->frac != 0);
}

# A number is zero if its exponent and fraction are both zero.
sub is_zero {
    return ($_[0]->exp == 0) && ($_[0]->frac == 0);
}

# A number is normalized if its exponent is neither all 1's ("special"
+ values)
# nor all 0's (denormalized values)
sub is_normalized {
    return !$_[0]->is_special && $_[0]->exp != 0;
}

sub as_string {
    my $self = shift;
    if ($self->is_NaN) { return 'NaN'; }
    if ($self->is_inf) { return ($self->sign > 0) ? '+Inf' : '-Inf' }
    if ($self->is_zero) { return ($self->sign > 0) ? '+0' : '-0' }
    if ($self->is_normalized) {
        return $self->sign * ( 1 + $self->frac ) * 2 ** ($self->exp -
+$self->bias);
    }
    else {
        return $self->sign * $self->frac * 2 ** (1 - $self->bias);
    }
}

sub details {
    my $self = shift;
    my @vals = (
        ($self->data) x 3, $self->k, $self->n, $self->bias, $self->sig
+n,
        $self->exp, $self->frac, $self->frac_bits, $self->is_normalize
+d
    );
    my $fmt = <<EOD;
  data: %d 0x%x 0b%08b
  k, n: %d, %d
  bias: %d
  sign: %d
   exp: %d
  frac: %f (@{[ $self->frac_bits ]})
normal: %d
 value: @{[ $self->as_string ]}
EOD
    return sprintf($fmt, @vals);
}

__END__

For a computer science course I'm taking, many examples in the book (not to
mention homework assignments) deal with the format floating-point values take
when stored in binary format.

Some of the examples and exercises deal with an "extended" IEEE 754 format
with eg. 8 bytes or 10 bytes, making pack() and similar utilities less than
useful. So I wrote this package to process data formatted similarly to
IEEE-754 float values.

This code is on the rough side; any feedback is welcome.
