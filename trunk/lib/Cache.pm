package Cache;
use strict;
 
use Cache::Memcached;

sub new {
	#return bless {},$_[0];
	return new Cache::Memcached { 'servers' => ['127.0.0.1:11211','216.239.114.231:11211','216.239.114.232:11211'], 'debug' => 0, 'compress_threshold' => 10_000 };
}
#sub get{}
#sub get_multi{}
#sub set{}
#sub delete{}

1;
