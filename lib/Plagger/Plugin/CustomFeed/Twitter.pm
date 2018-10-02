package Plagger::Plugin::CustomFeed::Twitter;
use strict;
use base qw( Plagger::Plugin );

use Plagger::UserAgent;
use Plagger::Util qw( decode_content );
use Web::Scraper;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'subscription.load' => $self->can('load'),
        );
}

sub load {
    my($self, $context) = @_;
    
    my $feed = Plagger::Feed->new;
    $feed->aggregator(sub { $self->aggregate(@_) });
    $context->subscription->add($feed);
}

sub aggregate {
    my ($self, $context, $args) = @_;

    foreach my $url (@{$self->conf->{uri}}) {
	$context->log(info => $url);
	my $agent = Plagger::UserAgent->new;

	my $res = $agent->fetch($url, $self);
	if ($res->http_response->is_error) {
	    $context->log(error => "GET $url failed: " . $res->status);
	    return;
	}
	my $html = decode_content($res);
	my $entry = scraper {
	    process 'p.tweet-text', post => 'HTML';
	    process 'a.tweet-timestamp', url => '@href';
	    process 'a.tweet-timestamp>span', date => '@data-time';
	    process 'span.username>b', id => 'TEXT';
	};
	my $res = scraper {
	    process 'title', 'title' => 'TEXT';
	    process 'div.content', 'entry[]' => $entry;
	}->scrape($html);

	my $feed = Plagger::Feed->new;
	$feed->type('twitter');
	$feed->link($url);
	$feed->title($res->{title});

	foreach my $line (@{$res->{entry}}){
	    my $entry  = Plagger::Entry->new;
	    my $id = $line->{id};
	    my $post = $line->{post};
	    my $title = substr(Plagger::Util::strip_html($post), 0, 100);

	    $context->log(debug => $post);
	    my $dt = eval { Plagger::Date->from_epoch($line->{date}) };
	    $entry->date($dt) if $dt;
	    $entry->body($post);
	    $entry->author($id);
	    $entry->title($title);
	    $entry->link(URI->new_abs($line->{url}, $url));
	    
	    $feed->add_entry($entry);
	}
	$context->update->add($feed);
    }
}

1;

__END__

=head1 NAME

Plagger::Plugin::CustomFeed::Twitter - Scraping Twitter HTML.

=head1 SYNOPSIS

  - module: CustomFeed::Twitter
    config:
       uri:
          - https://twitter.com/riywo
          - https://twitter.com/fujii0
          - https://twitter.com/search?q=emacs%20min_faves%3A1

=head1 DESCRIPTION

This plugin scrapes twitter HTML.
L<http://www.tumblr.com/>.

=head1 AUTHOR

riywo, Fujii Hironori

=head1 SEE ALSO

L<Plagger>

=cut
