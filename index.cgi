#!../rebol276 -cs
REBOL []

domain: "http://rebolforum.com/index.cgi"

temp: read %index.rsp

replace/all  temp "<%"  "}"

replace/all  temp "%>"  "^/ print {"

insert temp "print { "

append temp "}"

replace/all temp "index.rsp"  "index.cgi"

do load temp 

