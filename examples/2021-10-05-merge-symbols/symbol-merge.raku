use v6;
#use L1;
use L1::App;

my $app = L1::App.new;

say "[$*PID] L1 in MAIN           : ", L1.WHICH;
$app.collection.load-driver;
