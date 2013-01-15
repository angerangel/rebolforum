Rebol []

;import function
; Columns [ID ID2 Title post Author date]

temp: load %archive.db

author: "anonymous"
i: 0
j: 0

foreach item temp [
	j: 0
	++ i	
	title: first item
	temp2: copy item 
	temp2: next temp2
	foreach [post aut date ] temp2 [   
		++ j
		append post reform ["<br> <i>" aut  "</i>"]		
		db-insert archive reduce [i j title  post author date]
		]
	]
db-commit archive	
	
;db-delete/where archive [id > 0]