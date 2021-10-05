use v6;
#use L1;
unit class L1::L2::Collection;
use L1::L2::Collection::Driver;

has $.driver;

method load-driver {
    require ::("L1::L2::Collection::FS");
    say ::("L1::L2::Collection::FS").WHICH;
}

say "[$*PID] L1 in Collection     : ", L1.WHICH;
