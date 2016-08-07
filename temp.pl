
use 5.010;

$pi = 3.141592654;
print "input string:\n";
chomp ($str = <STDIN>);
print "input times:\n";
chomp ($n = <STDIN>);

print $str x $n;

