package Thread::Queue;

use strict;

our $VERSION = '1.00';

use Thread qw(cond_wait cond_broadcast);

BEGIN {
    use Config;
    if ($Config{useithreads}) {
	require 'threads/shared/queue.pm';
	for my $meth (qw(new enqueue dequeue dequeue_nb pending)) {
	    no strict 'refs';
	    *{"Thread::Queue::$meth"} = \&{"threads::shared::queue::$meth"};
	}
    } elsif ($Config{use5005threads}) {
	for my $meth (qw(new enqueue dequeue dequeue_nb pending)) {
	    no strict 'refs';
	    *{"Thread::Queue::$meth"} = \&{"Thread::Queue::${meth}_othread"};
	}
    } else {
        require Carp;
        Carp::croak("This Perl has neither ithreads nor 5005threads");
    }
}


=head1 NAME

Thread::Queue - thread-safe queues (for old code only)

=head1 CAVEAT

For new code the use of the C<Thread::Queue> module is discouraged and
the direct use of the C<threads>, C<threads::shared> and
C<threads::shared::queue> modules is encouraged instead.

For the whole story about the development of threads in Perl, and why you
should B<not> be using this module unless you know what you're doing, see the
CAVEAT of the C<Thread> module.

=head1 SYNOPSIS

    use Thread::Queue;
    my $q = new Thread::Queue;
    $q->enqueue("foo", "bar");
    my $foo = $q->dequeue;    # The "bar" is still in the queue.
    my $foo = $q->dequeue_nb; # returns "bar", or undef if the queue was
                              # empty
    my $left = $q->pending;   # returns the number of items still in the queue

=head1 DESCRIPTION

A queue, as implemented by C<Thread::Queue> is a thread-safe data structure
much like a list. Any number of threads can safely add elements to the end
of the list, or remove elements from the head of the list. (Queues don't
permit adding or removing elements from the middle of the list)

=head1 FUNCTIONS AND METHODS

=over 8

=item new

The C<new> function creates a new empty queue.

=item enqueue LIST

The C<enqueue> method adds a list of scalars on to the end of the queue.
The queue will grow as needed to accomodate the list.

=item dequeue

The C<dequeue> method removes a scalar from the head of the queue and
returns it. If the queue is currently empty, C<dequeue> will block the
thread until another thread C<enqueue>s a scalar.

=item dequeue_nb

The C<dequeue_nb> method, like the C<dequeue> method, removes a scalar from
the head of the queue and returns it. Unlike C<dequeue>, though,
C<dequeue_nb> won't block if the queue is empty, instead returning
C<undef>.

=item pending

The C<pending> method returns the number of items still in the queue.  (If
there can be multiple readers on the queue it's best to lock the queue
before checking to make sure that it stays in a consistent state)

=back

=head1 SEE ALSO

L<Thread>

=cut

sub new_othread {
    my $class = shift;
    return bless [@_], $class;
}

sub dequeue_othread : locked : method {
    my $q = shift;
    cond_wait $q until @$q;
    return shift @$q;
}

sub dequeue_nb_othread : locked : method {
  my $q = shift;
  if (@$q) {
    return shift @$q;
  } else {
    return undef;
  }
}

sub enqueue_othread : locked : method {
    my $q = shift;
    push(@$q, @_) and cond_broadcast $q;
}

sub pending_othread : locked : method {
  return scalar(@{(shift)});
}

1;
