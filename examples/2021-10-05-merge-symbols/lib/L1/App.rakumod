use v6;
#use L1;
unit class L1::App;
use L1::L2::Collection;

has $.collection;

submethod TWEAK {
    $!collection = L1::L2::Collection.new;
}

say "[$*PID] L1 in App            : ", L1.WHICH;
