
Rebol []



either  object? request [cgi: copy request/query-string]  [cgi: copy system/options/cgi/query-string ] ;this work both on Cheyenne and normal CGI webapp

cgi: context decode-cgi cgi ;so we create the cgi object




do %db.r


if (select cgi 'type) = "rss" [

print  {<?xml version="1.0"?>
        <rss version="2.0">
        <channel>        
        <title>REBOL Forum</title>
        <description>Recent REBOL Forum Topics</description>
        <link>http://rebolforum.com</link>
    }
    
    titles: db-select/where/order/desc  [ID title date ] archive [ID2 = 1]  ID  ;ID=2  are the firsts post of a thread
    foreach  [ID title date ]  titles [
	print [<item> <title> title </title> <link>]
	print rejoin [http://rebolforum/index.rsp?type=thread&ID=  ID]
	print [</link> <description> title </description><pubDate>date</pubDate></item>]
	]
    print {</channel></rss>}
quit 
]

print {<html>
<HEAD>
<TITLE>REBOL Forum</TITLE>
<link rel="alternate" type="application/rss+xml" title="rebolforum.com rss feed" href="./index.rsp?type=rss" /></HEAD>
<BODY >
<CENTER>
<h1>REBOL Forum</H1>}


;search result

if (select cgi 'type) = "search" [

print  {<h2>Seach result</h2>}
print {<table width=85% ><tr><td alig=left><a href=index.rsp>HOME</a></td>}		
print [{You searched <b>"}  cgi/query {"</b>}]
    
    result: db-select/where  [ID ID2 title post date ] archive [find/any post to-string cgi/query ]
     
    
    print {<table width=85% border=1 >
    <th>TITLE</th><th>POST</th><th>DATE</th>}
    foreach  [ID ID2 title post date]  result [
	q-page: round/ceiling  (ID2 / 10)
	print [ <tr> <td> rejoin ["<a href=index.rsp?type=thread&ID=" ID "&page=" q-page " >" ] title </a> </td>
		<td>post</td>
		<td>date</td>
		</tr>
		]
	]
          print </table> 
]


;useful functions

to-br: func [item] [
	replace/all item "^/" <br>
	item
	]



;single thread view
if (select cgi 'type) = "thread" [
	type: "thread"
	
	print {<table width=85% ><tr><td alig=left><a href=index.rsp>HOME</a></td>}	
	title: first db-select/where  [title]   archive [ID =  to-integer cgi/ID]   ;ID=2  are the firsts post of a thread
	
	print [<td align=rigth> <h2> title </h2></td> ]
	
	print {</tr></table>}
	;main table
	print {<table border=1  width=85% >
<tr> <th> User </th> <th>post</th></tr>}

	threads:  db-select/where/order  [ID2 title date Author post]   archive [ID =  to-integer cgi/ID]  ID2

	either select cgi 'page [page: to-integer cgi/page] [page: 1]	
	pages: round/ceiling ( (length? threads) / (5 * 10) )
	loop (( page - 1)  * 10 * 5 ) [
		threads: next threads
		]	
	threads2: copy []
	loop (10 * 5)  [
		append threads2 threads/1
		threads: next threads
		]

	foreach  [ID2 title date Author post] threads2 [
		if ID2 [ 
			print [ <tr> <td align=center width=30% > Author <br>  ]			
			avatar:  db-select/where  [avatar] users  [name = to-string Author]
			print rejoin ["<img src=" avatar " width=40px height=40px ><br>" ]
			print [<i><small>date</small></i></td>]
			print [<td> (to-br post)  </td></tr>]		
			]
		]
	print "</table>"	
	;navigation links	
	print "<table width=85% border=0>"
	print "<tr><td align=right colspan=4 >"
	if page > 1  [print [  rejoin ["<a href=index.rsp?type=thread&ID="  cgi/ID "&page=1>First</a> - " "<a href=index.rsp?type=titles&page=" (page - 1) ] ">  &lt; </a>"]]
	print [ " <b>" page "</b>/" pages " "  ]
	if pages > 1 [ print [rejoin ["<a href=index.rsp?type=thread&ID="  cgi/ID  "&page=" (page + 1)] "> &gt; </a>"  rejoin ["- <a href=index.rsp?type=titles&ID="  cgi/ID  "&page=" pages ">Last</a>" ] ]]	
	print "</td></tr></table>"
	
	]


;all threads view
if any [
	(select cgi 'type) = none 
	(select cgi 'type) = "titles"
	][
	type:  "titles"
	print {<table width=85% ><tr> <td align=right > Login - Register </td></table>}
	;search box
	print {<form action="./index.rsp"	method=get >
		<input type=hidden name="type" value="search">
		<input type=text name=query size=65 ><input type="submit" value=Search >
		</form>
		}
	
	;main table
	PRINT {<table border=1 cellpadding=10 width=85% >
<tr> <th> TITLE </th> <th>POSTS</th><th>DATE</th><th>AUTHOR</th></td>}
	titles: db-select/where/order/desc  [ID title date Author] archive [ID2 = 1] ID  ;ID=2  are the firsts post of a thread
	either select cgi 'page [page: to-integer cgi/page] [page: 1]	
	pages: round/ceiling ( (length? titles) / ( 4 * 10) ) ;10 titles per page
	loop (( page - 1)  * 10 * 4 ) [
		titles: next titles
		]	
	titles2: copy []
	loop (10 * 4 )  [
		append titles2 titles/1
		titles: next titles
		]

	foreach  [IDt title date Author] titles2 [
		if IDt [ print [ <tr> 
			<td>  (rejoin ["<a href=./index.rsp?type=thread&ID=" IDt ])  ">"  title </a> </td>			
			 <td> db-select/count/where [ ID ] archive [ ID = to-integer IDt ]</td>			
			 <td>date</td>
			<td>Author</td></tr>
			]]
		]
	print "</table>"	
	;navigation links	
	print "<table width=85% border=0>"
	print "<tr><td align=right colspan=4 >"
	if page > 1  [print [  rejoin ["<a href=index.rsp?type=titles&page=1>First</a> - " "<a href=index.rsp?type=titles&page=" (page - 1) ] ">  &lt; </a>"]]
	print [ " <b>" page "</b>/" pages " "  ]
	if pages > 1 [ print [rejoin ["<a href=index.rsp?type=titles&page=" (page + 1)] "> &gt; </a>"  rejoin ["- <a href=index.rsp?type=titles&page=" pages ">Last</a>" ] ]]	
		print "</td></tr></table>"
	do %captcha.r	
	captcha/set-fonts-path %fonts/  
	image: load captcha/generate
	save/png %captcha.png image
	print [ {<form action="./index.rsp" method=post >
		<input type=hidden name="type" value="newpost">		
		<table>
		<tr><td>Name:</td><td> <input type=text name=user size=65 ></td><tr>
		<tr><td>New topic: </td><td><input type=text name=title size =65></td><tr>
		<tr><td>Message:</td><td> <textarea name=post rows=5 cols=50 ></textarea></td></tr>
		<tr><td ></td><td><img src=captcha.png> } 
		{</td></tr>
		<tr><td>Captcha: </td><td> <input type=text name=captcha >  </td><tr>
		<tr><td></td><td><input type="submit" ><input type=reset></td></tr>
		</table>
		</form>
		}]
		
	]
	

print { <hr>
<table >
<tr  ><td><a href=http://www.dobeash.com/rebdb.html><img height=40px src=pwr-rebdb.png></a></td>
<td><a height=40px href=http://www.rebol.com><img src=pwr-rebol100.gif height=40px ></a></td>
<td><a height=40px href=http://softinnov.org/><img src=softinnov.png height=40px ></a></td>
<td></td></tr>
</table>
<a href=./index.r>source</a> 
-
<a href=./index.rsp?type=rss>rss</a> 
-
<a href="./index.rsp"><strong>Home</strong></a> 
-
<a href="./index.rsp?type=rss">RSS Feed</a> 
-
<a href="./index.cgi?type=downloadreader">Reader</a>
-
<a href="./index.cgi?type=source">Source</a> 
-
<a href="http://synapse-ehr.com/community/forums/rebol.5/" target=_blank>Graham's Forum</a> 
-
<a href="http://www.rebol.org/aga-groups-index.r?world=r3wp" target=_blank>AltME</a> 
- 
<a href="http://mail.rebol.net/cgi-bin/mail-list.r" target=_blank>ML</a> 
- 
<a href="http://www.rebol.net/cgi-bin/r3blog.r" target=_blank>R3 Blog</a> 
-
<a href="http://translate.google.com/translate?hl=en&sl=fr&u=http://www.digicamsoft.com/cgi-bin/rebelBB.cgi&ei=te4HTNCBGsKBlAfdnIyZDg&sa=X&oi=translate&ct=result&resnum=1&ved=0CCsQ7gEwAA&prev=/search%3Fq%3Drebelbb%26hl%3Den%26client%3Dopera%26hs%3DF5Z%26rls%3Den" target=_blank>RebelBB</a> 
- 
<a href="http://www.rebol.com/community.html" target=_blank>Community</a> &nbsp; 
- 
<a href="http://re-bol.com" target=_blank>Tutorial</a> 
</html>}