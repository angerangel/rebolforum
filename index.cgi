#!../rebol276 -cs
REBOL []

domain: "http://rebolforum.com/index.cgi"

print {content-type: text/html^/}

switch system/options/cgi/request-method [
    "POST" [
        cgi-data: copy ""  cgi-buffer: copy ""
        while [positive? read-io system/ports/input cgi-buffer 16380] [
            append cgi-data cgi-buffer clear cgi-buffer
        ]
    ]
    "GET" [cgi-data: system/options/cgi/query-string]
]
submitted: decode-cgi cgi-data

if submitted/2 = "rss" [
    write/append %bb.db ""
    bbs: load %bb.db
    reverse bbs
    stickycount: 0
    foreach topic bbs [foreach item topic [if find item {<i>STICKY:} [stickycount: stickycount + 1]]]
    print trim {<?xml version="1.0"?>
        <rss version="2.0">
        <channel>        
        <title>REBOL Forum</title>
        <description>Recent REBOL Forum Topics</description>
        <link>http://rebolforum.com</link>
    }
    count: 1
    foreach item (at bbs (stickycount + 1)) [
        rss-title: copy item/1
        rss-title: replace/all rss-title {&} {&amp;}
        rss-title: replace/all rss-title {"} {&quot;}
        rss-title: replace/all rss-title {'} {&apos;}
        rss-title: replace/all rss-title {<} {&lt;}
        rss-title: replace/all rss-title {>} {&gt;}
        rss-description: rejoin [
            (copy/part (pick item ((length? item) - 2)) 4096) 
            ", Posted by: " (pick item ((length? item) - 1))
            "  " (pick item (length? item))
        ]
        rss-description: replace/all rss-description {&} {&amp;}
        rss-description: replace/all rss-description {"} {&quot;}
        rss-description: replace/all rss-description {'} {&apos;}
        rss-description: replace/all rss-description {<} {&lt;}
        rss-description: replace/all rss-description {>} {&gt;}
        print trim rejoin [
            {<item>
            <title>} rss-title {</title>
            <description>} rss-description {</description>
            <link>http://rebolforum.com/index.cgi?f=printtopic&amp;topicnumber=}
            ((length? bbs) + 1 - count - stickycount) {&amp;archiveflag=new</link>
            </item>}
        ]
        count: count + 1
        if count > 10 [break]
    ]
    print trim {
        </channel>
        </rss>
    }
    quit
]

print {<HTML><HEAD><TITLE>REBOL Forum</TITLE><link rel="alternate" type="application/rss+xml" title="rebolforum.com rss feed" href="./index.cgi?f=rss" /></HEAD>
<BODY bgColor=#808080><CENTER>
<TABLE border=0 cellPadding=20 cellSpacing=2 height=100% width=85%>
<TR><TD bgColor=white vAlign=top>}

footer: {</TD></TR></TABLE></CENTER></BODY></HTML>}

unless exists? %index.html [
    write %index.html {<html><head><title></title><META HTTP-EQUIV="REFRESH" CONTENT="0; URL=./index.cgi"></head><body bgcolor="#FFFFFF"></body></html>}
]

if submitted/2 = "downloadreader" [
    print trim/lines {
        <center><a href="./index.cgi?f=home">Home</a></center><br>
        (Open the REBOL console and "do" this page URL)<br><br><pre>
    }
    print decompress #{
789CC5544B8BDB3010BEFB570C82425C70B4CE52167C6B69F7B4A5901E430EB2
3DD9A8B525571AC7D996FEF74AF2234EB2DBC7A9821069E69BC7F78DA5F58777
9F1E6043922ACC80ADC3F15E9BB686358A120DDB46912D0CA2CAC03E59C29A1F
2476BCB7253B5120B7F23B4202E9CDCDD1FD22D28D2C6C06856E9E60B3052805
895C589C4C51D436CEE80CA5460B9B08DCBA080BB68BC84A8BD2E1929DAC100C
7E6BD15238F04080FB6D88F38B3D78F447B4563CA2CD183006AF0CE6BADA797E
4B3A52C0BA138A62DFD79F2A0E4DF9259A065539F4073B692CF58780E81BA594
FBC8A1CF1E1A1C76AF3BE70D7B9172C2230DA01F3F4F0091464E142F2C14A808
4D10162AF1A45B1A5A092A2F7ADDE33E5F61B4B543FD0C7CEEA492AEBBC542D8
A411D2C0C2E856959CF418C953780DCBD59B18D278B2ADE2D8CD6F757BBCBB8D
830223D99308F5A863DF3C639367D46F334040891A81648D5B58080297E8EB49
562754A10856F12CF74CE4B18C9BEE172DD50568D60828EC2AA966FFBE2A7363
0FA52FDD576958F277CB65FC5DAA6D74BD3B1FF3C868728F033F0509373CE144
84CE88E6CFC3BB7B7978219D416A8D0ADB9C14B0F7BA53E1E6ACD17F5CD39560
33753B23099FBF5A561C9EBD5F41C5CFCE392574F170EF202FDFB57139B225EC
899A8CF319ACD035CFF36599CFC439A7F0D6147B79C0F23F9048445FFB5FC88C
21D78CFCEB0A23AD733EFDDBE8DECD68FB0BE01DA7BF9F050000
}
    print {</pre>}
    print footer
    quit
]

if submitted/2 = "api" [
    print {<pre>}
    print decompress #{
789CB5503D0BC23010DDFB2B8E0E3A15F74217C14E82E01A3AC4F62A912629F9
4044FADF4DD3D8D6A238883784BCBB07EFE3B8DB1EF6400C330DA6101F3DCCA5
B21C722B4AC3A4D0711145B4AA14EAD62147ABDD0548DDB312AB1A187E46B6AC
14969F50858DD5A804E5182047ADE9190B2010811B7E4B5AA94D0A0A2F920920
7EDBCFBD0EDAD94CB79BCEAB9956D6BDD19F517B032367743423045B232760CF
28FCAB90569BD26A23394CA91556B64420EB3EC4334C110D6509BC7EEA69D18A
B7FD5B434EACFB967859DE6B6D7FEDE30149C2C94C64020000
}
    print {</pre>}
    print footer
    quit
]

if submitted/2 = "source" [
    print trim/lines {
        <center><a href="./index.cgi?f=home">Home</a></center><br>
        (Open the REBOL console and "do" this page URL)<br><br><pre>
    }
    prin {REBOL []  editor decompress }
    print compress read %index.cgi
    print </pre>
    print footer
    quit
]

write/append %archive.db ""
write/append %bb.db ""
bbs: load %bb.db
displaylength: 49

captchacheck: does [
    if submitted/10 <> (trim/all reverse submitted/12) [
        print {<strong>Incorrect Captcha Text</strong><br><br>
            Click the [BACK] button in your browser to try again.
            <br><br><a href="./index.cgi?f=home">Home</a><br>
        }
        print footer
        quit
    ]
    if ((submitted/4 = submitted/6) or (submitted/2 = submitted/4) or (submitted/2 = submitted/6)) [
        print {<strong>Name and Entry Should NOT match</strong><br><br>
            Click the [BACK] button in your browser to try again.
            <br><br><a href="./index.cgi?f=home">Home</a><br>
        }
        print footer
        quit
    ]
]

random/seed now/time  password: copy []  wrds: first system/words
foreach ch mold pick wrds (random length? wrds) [append password ch]
password: reverse password

if submitted/2 = "addnew" [
    if (submitted/4 = "") or (submitted/6 = "") or (submitted/8 = "") [
        print {
            <strong>Incomplete submission</strong><br><br>
            Click the [BACK] button in your browser to try again.
            <br><br><a href="./index.cgi?f=home">Home</a><br>
        }
        print footer
        quit
    ]
    captchacheck
    make-dir %./history/
    save rejoin [
        %./history/ now/year "_" now/month "_" now/day "_" 
        (replace/all form now/time ":" "_") ".db"
    ] bbs
    entry: copy []
    append entry submitted/6  ; topic
    submitted-message: replace/all submitted/8 {REBOL [} {R E B O L [}
    submitted-message: replace/all submitted-message {REBOL[} {R E B O L [}
    append entry submitted-message  ; message
    append entry submitted/4  ; name
    append entry form (now + 3:00)
    append/only tail bbs entry
    if (length? bbs) > displaylength [
        write/append %archive.db mold bbs/1
        remove head bbs
    ]
    reverse bbs
    foreach topic (copy bbs) [ 
       foreach item topic [
           if find item {<i>STICKY:} [
               move/to (find/only bbs topic) 1
           ]
       ]
    ]
    reverse bbs
    save %bb.db bbs
    print {<strong>New Topic Added</strong>}
    print footer
    wait :00:02
    print {<META HTTP-EQUIV="REFRESH" CONTENT="0; URL=./index.cgi?f=added">}
    quit
]

if submitted/2 = "printtopic" [
    either submitted/6 = "archive" [
        bbs: load %archive.db
        archiveflag: "archive"
    ] [
        archiveflag: "new"
    ]
    either (form submitted/3) = "permalink" [
        permc: 1
        foreach topic bbs [
            if submitted/4 = (join topic/3 topic/4)[current-topic: copy pick bbs permc]
            permc: permc + 1
        ]
    ] [
        current-topic: copy pick bbs (to-integer submitted/4) 
    ]    
    print rejoin [
        {<center><a href="./index.cgi?f=home">Home</a> &nbsp; 
        <a href="./index.cgi?f=printarchive">Archive</a> &nbsp; 
        <a href="} domain {?f=printtopic&permalink=} join current-topic/3 current-topic/4 
        {&archiveflag=} archiveflag {">Permalink</a></center><br>
        <center><table border=0 cellPadding=0 cellSpacing=0 width=90%><tr><td><hr><br>
        <font size=5>} (current-topic/1) {</font><br><br>}
    ]
    foreach [message name timestamp] (at current-topic 2) [
        replace/all message "<" "&lt;"
        replace/all message "&lt;i>" "<i>"
        replace/all message "&lt;/i>" "</i>"
        replace/all message "&lt;strong>" "<strong>"
        replace/all message "&lt;/strong>" "</strong>"
        replace/all message "&lt;b>" "<b>"
        replace/all message "&lt;/b>" "</b>"
        replace/all message newline {  <br>  }
        message2: copy message
        append message { } 
        replace/all message2 {    } {&nbsp;&nbsp;&nbsp;&nbsp;} 
        replace/all message2 #(tab) {&nbsp;&nbsp;&nbsp;&nbsp;} 
        replace/all message2 {^-} {&nbsp;&nbsp;&nbsp;&nbsp;}
        parse/all message [any [thru "http://" copy link to { } (replace message2 (rejoin [{http://} link]) (rejoin [{ <a href="} {http://} link {" target=_blank>http://} link {</a> }]))] to end]
        print rejoin [
            message2 {<br><br><font size=1>posted by: &nbsp; }
            name { &nbsp; &nbsp; &nbsp; }
            timestamp {</font><br><br><hr><br>}
        ]
    ]
    if submitted/6 = "new" [
        print rejoin [
            {<FORM method="post" ACTION="./index.cgi">
                <input type=hidden name="addresponse" value="addresponse">
                <input type=hidden name="topicnumber" value="} current-topic/1 {">
                Name: <br>
                <input type=text size="60" name="username"><br><br>
                Message: <br>
                <textarea name=message rows=5 cols=50></textarea><br><br>
                Type the <i>reverse</i> of this captcha text: "<strong>} password {</strong>"<br><br>
                <input type=text size="60" name="pass"><br><br>
                <input type="hidden" name="password" value="} password {">
                <input type="submit" name="submit" value="submit response">
            </FORM></td></tr>
            <tr><td align=right><a href="./index.cgi?f=home">Home</a></td></tr></table></center>}
        ]
    ]
    print footer
    quit
]

if submitted/2 = "search" [
    print {<center><a href="./index.cgi?f=home">Home</a></center><br><hr><br>}
    search-all: does [
        foreach topic bbs [
            foreach [message name timestamp] (at topic 2) [
                if any [(find message submitted/4) (find name submitted/4)] [
                    replace/all message newline {  <br>  }
                    message2: copy message
                    append message { } 
                    replace/all message2 {    } {&nbsp;&nbsp;&nbsp;&nbsp;} 
                    parse/all message [any [thru "http://" copy link to { } (replace message2 (rejoin [{http://} link]) (rejoin [{ <a href="} {http://} link {" target=_blank>http://} link {</a> }]))] to end]
                    print rejoin [
                        {<font size=5>} archive-note topic/1 {</font><br><br>}
                        message2 {<br><br><font size=1>posted by: &nbsp; }
                        name { &nbsp; &nbsp; &nbsp; }
                        timestamp {</font><br><br><hr><br>}
                    ]
                ]
            ]
        ]
    ]
    archive-note: ""  search-all  
    bbs: load %archive.db  archive-note: {(Archive) }  search-all
    print footer
    quit
]

if submitted/2 = "addresponse" [
    if (submitted/6 = "") or (submitted/8 = "") [
        print {
            <strong>Incomplete submission.</strong><br><br>
            Click the [BACK] button in your browser to try again.
            <br><br><a href="./index.cgi?f=home">Home</a><br>
        }
        print footer
        quit
    ]
    captchacheck
    save rejoin [
        %./history/ now/year "_" now/month "_" now/day "_" 
        (replace/all form now/time ":" "_") ".db"
    ] bbs
    ; topicnumber: to-integer submitted/4    ; topic number
    ; topicnumber: index? find/only bbs submitted/4
    topicnumber: 1
    foreach topic bbs [either topic/1 = submitted/4 [break][topicnumber: topicnumber + 1]] 
    submitted-message: replace/all submitted/8 {REBOL [} {R E B O L [}
    submitted-message: replace/all submitted-message {REBOL[} {R E B O L [}
    append bbs/:topicnumber submitted-message    ; message 
    append bbs/:topicnumber submitted/6    ; name
    append bbs/:topicnumber form (now + 3:00)
    move/to (at bbs topicnumber) (length? bbs)  ; sort messages by most recent
    responded-topic: (first last bbs)
    reverse bbs  ; move sticky messages to top
    foreach topic (copy bbs) [ 
       foreach item topic [
           if find item {<i>STICKY:} [
               move/to (find/only bbs topic) 1
           ]
       ]
    ]
    reverse bbs
    save %bb.db bbs
    print rejoin [{<strong>Response added to "} responded-topic {"</strong>}]
    print footer
    wait :00:03
    print {<META HTTP-EQUIV="REFRESH" CONTENT="0; URL=./index.cgi?f=added">}
    quit
]

either submitted/2 = "printarchive" [
    archiveflag: "archive"
    bbs: load %archive.db
    head-text: "Archive"
] [
    archiveflag: "new"
    head-text: "REBOL Forum"
]
print rejoin [{
    <center><font size=6>} head-text {</font><br>
    <FORM method="post" ACTION="./index.cgi">
        <input type=hidden name="search" value="search">
        <input type=text size="50" name="searchtext">
        <input type="submit" name="submit" value="search">
    </FORM>
    <table border=1 cellPadding=5 cellSpacing=0 width=90%>
}]
counter: 1
reverse bbs
foreach bb bbs [
    print rejoin [
        {<tr><td width=65%> &nbsp; <a href="./index.cgi?f=printtopic&topicnumber=}
        ((length? bbs) + 1 - counter)
        {&archiveflag=} archiveflag {">} bb/1 
        {</a></td><td width=5%>} ((length? bb) - 1 / 3)
        {</td><td width=30%><font size=1>} (last bb) 
        {, } pick bb ((length? bb) - 1) {</font></td></tr>}
    ]
    counter: counter + 1
    if ((counter > displaylength) and (archiveflag = "new")) [break] 
]
message-count: 0
try [foreach record bbs [
    message-count: message-count + ((length? record) - 1 / 3)
]]
either submitted/2 <> "printarchive" [
    print rejoin [
        {<tr><td><strong> &nbsp; } message-count { live messages </strong></td>}
        {<td colspan=2 align=center> &nbsp; <a href="./index.cgi?f=printarchive">ARCHIVED MESSAGES</a></td></tr>}
    ]
] [
    print rejoin [
        {<td colspan=2> &nbsp; <strong>} message-count { archived messages</strong></td>}
        {<td align=center> &nbsp; <a href="./index.cgi?f=home">Home</a></td></tr>}
    ]
]
print rejoin [{
    </table><br>
    <FORM method="post" ACTION="./index.cgi">
        <table border=0 cellPadding=0 cellSpacing=4 width=50%>
        <input type=hidden name="addnew" value="addnew">
        <tr><td width=10%>Name:</td>
        <td><input type=text size="65" name="username"></td></tr>
        <tr><td width=10%>New&nbsp;Topic:</td>
        <td><input type=text size="65" name="subject"></td></tr>
        <tr><td width=10%>Message:</td>
        <td><textarea name=message rows=5 cols=50></textarea></td></tr>
        <tr><td width=10%>Captcha:</td>
        <td>Type the <i>reverse</i> of this captcha text: "<strong>} password {</strong>"<br>
        <input type=text size="65" name="pass"><br>
        <input type="hidden" name="password" value="} password {"></td></tr>
        <tr><td></td><td><input type="submit" name="submit" value="submit new topic"></td></tr>
        </table>
    </FORM>
    <table border=1 cellPadding=5 cellSpacing=0 width=88%><tr><td align=center><font size=2>
        <a href="./index.cgi?f=home"><strong>Home</strong></a> &nbsp; 
        <a href="./index.cgi?f=rss">RSS Feed</a> &nbsp; 
        <a href="./index.cgi?f=downloadreader">Reader</a> &nbsp; 
        <a href="./index.cgi?f=source">Source</a> &nbsp; 
        <a href="http://synapse-ehr.com/forums/forumdisplay.php?3-Rebol" target=_blank>Graham's Forum</a> &nbsp; 
        <a href="http://www.rebol.org/aga-groups-index.r?world=r3wp" target=_blank>AltME</a> &nbsp; 
        <a href="http://mail.rebol.net/cgi-bin/mail-list.r" target=_blank>ML</a> &nbsp; 
        <a href="http://www.rebol.net/cgi-bin/r3blog.r" target=_blank>R3 Blog</a> &nbsp; 
        <a href="http://translate.google.com/translate?hl=en&sl=fr&u=http://www.digicamsoft.com/cgi-bin/rebelBB.cgi&ei=te4HTNCBGsKBlAfdnIyZDg&sa=X&oi=translate&ct=result&resnum=1&ved=0CCsQ7gEwAA&prev=/search%3Fq%3Drebelbb%26hl%3Den%26client%3Dopera%26hs%3DF5Z%26rls%3Den" target=_blank>RebelBB</a> &nbsp; 
        <a href="http://www.rebol.com/community.html" target=_blank>Community</a> &nbsp; 
        <a href="http://re-bol.com" target=_blank>Tutorial</a>
    </font></td></tr></table></center>
}]
print footer
quit
