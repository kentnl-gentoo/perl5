#!./perl

# Test ability to retrieve HTTP request info
######################### We start with some black magic to print on failure.

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib' if -d '../lib';
}

BEGIN {$| = 1; print "1..17\n"; }
END {print "not ok 1\n" unless $loaded;}
use CGI (':standard','-no_debug');
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# util
sub test {
    local($^W) = 0;
    my($num, $true,$msg) = @_;
    print($true ? "ok $num\n" : "not ok $num $msg\n");
}

# all the automatic tags
test(2,h1() eq '<H1>',"single tag");
test(3,h1('fred') eq '<H1>fred</H1>',"open/close tag");
test(4,h1('fred','agnes','maura') eq '<H1>fred agnes maura</H1>',"open/close tag multiple");
test(5,h1({-align=>'CENTER'},'fred') eq '<H1 ALIGN="CENTER">fred</H1>',"open/close tag with attribute");
test(6,h1({-align=>undef},'fred') eq '<H1 ALIGN>fred</H1>',"open/close tag with orphan attribute");
test(7,h1({-align=>'CENTER'},['fred','agnes']) eq 
     '<H1 ALIGN="CENTER">fred</H1> <H1 ALIGN="CENTER">agnes</H1>',
     "distributive tag with attribute");
{
    local($") = '-'; 
    test(8,h1('fred','agnes','maura') eq '<H1>fred-agnes-maura</H1>',"open/close tag \$\" interpolation");
}
test(9,header() eq "Content-Type: text/html\r\n\r\n","header()");
test(10,header(-type=>'image/gif') eq "Content-Type: image/gif\r\n\r\n","header()");
test(11,header(-type=>'image/gif',-status=>'500 Sucks') eq "Status: 500 Sucks\r\nContent-Type: image/gif\r\n\r\n","header()");
test(12,header(-nph=>1) eq "HTTP/1.0 200 OK\r\nContent-Type: text/html\r\n\r\n","header()");
test(13,start_html() ."\n" eq <<END,"start_html()");
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<HTML><HEAD><TITLE>Untitled Document</TITLE>
</HEAD><BODY>
END
    ;
test(14,start_html(-dtd=>"-//IETF//DTD HTML 3.2//FR") ."\n" eq <<END,"start_html()");
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 3.2//FR">
<HTML><HEAD><TITLE>Untitled Document</TITLE>
</HEAD><BODY>
END
    ;
test(15,start_html(-Title=>'The world of foo') ."\n" eq <<END,"start_html()");
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<HTML><HEAD><TITLE>The world of foo</TITLE>
</HEAD><BODY>
END
    ;
test(16,($cookie=cookie(-name=>'fred',-value=>['chocolate','chip'],-path=>'/')) eq 
     'fred=chocolate&chip; path=/',"cookie()");
test(17,header(-Cookie=>$cookie) =~ m!^Set-Cookie: fred=chocolate&chip\; path=/\r\nDate:.*\r\nContent-Type: text/html\r\n\r\n!s,
     "header(-cookie)");