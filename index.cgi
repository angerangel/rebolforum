#!../rebol276 -cs
REBOL []

domain: "http://rebolforum.com/index.cgi"

temp: read %index.r

replace/all temp "index.rsp"  "index.cgi"

do load temp 

