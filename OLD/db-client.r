REBOL [
	Title:		"RebDB client"
	Owner:		"Ashley G. Trüter"
	Version:	2.0.3
	Date:		13-Apr-2007
	Purpose:	"Client-side DB functions."
	History: {
		2.0.0	Initial release
		2.0.1	Minor fixes and enhancements
		2.0.2	Added "set path" option (to change db/base-dir)
				Added "set lines" option (to change db/lines?)
				Removed set-browser-path and set browser option (depreciated in 2.6.0)
		2.0.3	Added joins and on
				Added replaces and with
				Added debug option
				Updated 'sql function to handle strings and : args
	}
]

client: context [

	help: #{
789CBD95C16E9B401086EF798A514E55ACF6057AA8306C03CAC2A25D8813593D
501BA7A806525837AD8077EF2CD875D48297A4A67B586469F4CF3F33DF8E676F
CF79661735F0FC09782C8B24FE1E6DE1DF4E7D313BBB3FCAD84DE8838C3E6F63
A8BEC63F618957F9A97995BF1A04A1C40CA0BA8255BEDDA5192CAB227F4AD6CD
FEB752FEC899BBCFA8D5536761134E9E9B83E52ACFD6894CF2EC254E0F7AD79C
61C9F37BA80E1E8FDEDED8C6ADE35D8FCA70D063DC227C40AFB28830475A9C62
BE8A3F37CAA287388D3339BA55FFCD9F85BC04E43912AF87700A5E1C4F101EE0
27607B7FB7060D8940AEB3F8876C009FF52EC61423F5021E7AA681158FE07F8C
5EE85B473541823E06D17AD5DA84E5DE6DD3DBE5F3F76F242F63C354FFDA4235
44E3D8B24D5EA491723CBC76A7F0675226B077DD3CAE067A55776B01D4C59D39
69FA6950F33099EB3A8146B00672E753C3F1A094911CEC4BABC7C99197DF8CFC
A5C7D9426811557A1667BE3E1084CD1627028E7A9C513A37CC9B93152306C69C
920F9AC4079EF5893B3DA1F537012F799A46D9BAD4F813B19449F6A0099BC0DF
7BB5505245D489775FB79BC7B02C4E84805D31F0E2D43C8869E33692B83AE152
DD97FDF3557A76E052A8F20CF2CDA63779AB7787AF43773A3DEA7838E213824A
CF26D41FA9E71B810D8F91FC3218A6780E3DA8CA55913C4AE83EEFCA6FDB3FB2
777AC2670C0BDE248874AFC317F0ACF442FCE7F20C97E05228909D3E7F67E6E5
17B6B451BC3F0B0000
}

	;	----------------------------------------
	;		Settings
	;	----------------------------------------

	address:	none
	html:		none
	spool:		none
	username:	none
	debug:		none

	;	----------------------------------------
	;		Context variables
	;	----------------------------------------

	buffer:		none	; stores result of db call
	table:		none	; table name
	cols:		none	; number of columns
	rows:		none	; number of rows
	columns:	none	; column names

	reserved-words:	[	; 'rowid must appear first as 'sql relies on this
		rowid avg by count desc distinct explain from group having header into joins max min on order replaces set std sum table to values where with
	]

	;	----------------------------------------
	;		Client / Server functions
	;	----------------------------------------

	db-request: function [
		"Send request to db and return reply."
		statement [block!] "SQL statement"
	][
		port
	][
		if none? attempt [
			port: open/binary/direct address
			insert port rejoin [username ":" mold/all/only statement]
			buffer: load decompress copy wait port
			close port
		][
			to-error "Could not connect to database"
		]
		if object? buffer [to-error form buffer/arg1]
		buffer
	]

	set 'sql function [
		"Transforms a SQL statement into a db function call."
		statement [string! block!] "SQL statement"
		/no-execute
	][
		explain?
		spec
		args
	][
		;	pre-proccess
		case [
			string? statement [statement: to-block statement]
			string? first statement [
				spec: copy first statement
				repeat i -1 + length? statement [
					replace/all spec join ":" i pick statement i + 1
				]
				statement: to-block spec
			]
		]
		;	process statement block
		explain?: either 'explain = first statement [remove statement true][false]
		spec: join "db-" first statement
		args: copy []
		foreach word next statement [
			;	ignore 'rowid
			either find next reserved-words word [
				;	ignore "fill" words
				unless find [by from into on set table to values with] word [
					insert tail spec join "/" word
				]
			][
				insert/only tail args word
			]		
		]
		insert tail spec join " " mold/only/all args
		if explain? [insert spec "explain/header [" insert tail spec "]"]
		either no-execute [
			buffer: spec
		][
			either address [db-request to-block spec][buffer: do spec]
		]
	]

	;	----------------------------------------
	;		Output formats
	;	----------------------------------------

	pad: func [
		value [any-type!] width [integer!]
	][
		either any [
			any-string? value
			word? value
			datatype? value
		][
			;	replace newline with char 182 for display
			value: replace/all form value "^/" "¶"
			either width > length? value [
				head insert/dup tail value " " width - length? value
			][
				copy/part value width
			]
		][
			head insert/dup value: form value " " width - length? value
		]
	]

	emit-ASCII: has [
		format
		separator
		size
	][
		format: copy []
		separator: copy "^/"
		;	format
		repeat pos cols [
			;	calculate max column width
			size: length? form columns/:pos
			buffer: at buffer pos
			loop rows [
				size: max size length? form first buffer
				buffer: skip buffer cols
			]
			buffer: head buffer
			;	build format masks
			prin pad form columns/:pos size + 1
			insert/dup tail separator "-" size
			insert tail separator " "
			insert tail format reduce ['pad columns/:pos size]
		]
		print separator
		;	print results
		do compose/deep	[
			foreach [(columns)] buffer [
				print trim/tail reform [(format)]
			]
		]
	]

	emit-HTML: has [
		page offset
	][
		page: copy []
		;	<html>
		insert page rejoin [
			{<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"><html><head><title>}
			table
			{</title><style type="text/css">}
			"body {font-size: 12pt; font-family: sans-serif}"
			"h1 {font-size: 24pt; font-family: serif}"
			"th {padding: 6pt; background-color: black; color: white; font-variant: small-caps}"
			"td {padding: 3pt}"
			{</style></head><body><h1>}
			table
			{</h1><table border="1" cols="} cols {" summary="RebDB Table"><colgroup>}
		]
		;	<colgroup>
		repeat pos cols [
			insert tail page either find [integer! money! decimal!] type? buffer/:pos [
				{<col align="right">}
			][
				{<col align="left">}
			]
		]
		;	<th>
		insert tail page "</colgroup><tr>"
		foreach column columns [
			insert tail page rejoin ["<th>" column "</th>"]
		]
		insert tail page "</tr>"
		;	<tr>
		offset: 1
		loop rows [
			insert tail page "<tr>"
			loop cols [
				insert tail page either any [none? buffer/:offset buffer/:offset = ""][
					copy "<td>&nbsp;</td>"
				][
					rejoin ["<td>" buffer/:offset "</td>"]
				]
				offset: offset + 1
			]
			insert tail page "</tr>"
		]
		;	</html>
		insert tail page "</table></body></html>"
		write html page
		page: none
		browse html
	]

	;	----------------------------------------
	;		Run & Execute
	;	----------------------------------------

	run: function [
		script [file!]
	][
		time
	][
		if %.sql <> suffix? script [script: join script %.sql]
		either exists? script [
			time: now/time
			foreach line read/lines script [execute/script line]
			print ["^/" script "ran in" now/time - time "second(s)"]
		][
			print [script "not found"]
		]
	]

	execute: function [
		statement [string!]
		/script
	][
		time
		error
	][
		unless empty? statement: to-block statement [
			if all [script 'echo <> first statement] [print ["RUN>" statement]]
			;	command or statement?
			switch/default first statement [
				echo	[print form next statement]
				exit	[quit]
				help	[print decompress help]
				run		[
					if 2 = length? statement [
						run to-file second statement
					]
				]
				set		[
					either 3 <= length? statement [
						switch second statement [
							address		[address: third statement]
							debug		[
								debug: either find [false off none] third statement [false] [true]
							]
							html		[
								either find [false off none] third statement [html: none][
									html: to-file third statement
									if %.html <> suffix? html [html: join html %.html]
								]
							]
							lines		[
								db/lines?: either find [false off none] third statement [false] [true]
							]
							path		[
								db/base-dir: dirize to-rebol-file form third statement
							]
							spool		[
								either find [false off none] third statement [spool: none][
									spool: to-file third statement
									unless find [%.txt %.lst %.log] suffix? spool [spool: join spool %.txt]
								]
								echo spool
							]
							username	[username: form third statement]
						]
					][
						print rejoin [
							"Address  " address
							"^/Debug    " debug
							"^/HTML     " html
							"^/Lines    " db/lines?
							"^/Path     " to-local-file db/base-dir
							"^/Spool    " spool
							"^/Username " username
						]
					]
				]
			][
				;	execute statement
				time: now/time
				if error? set/any 'error try [
					;	prepare
					if find [desc describe insert lookup select show tables] first statement [
						insert tail statement 'header
					]
					;	execute
					either debug [
						sql/no-execute statement
					][
						sql statement
					]
					time: now/time - time
					either block? buffer [
						either empty? buffer [
							print ["^/0 row(s) selected in" time "seconds"]
						][
							;	set table properties and remove header block
							columns: last buffer
							remove back tail buffer
							table: first columns
							remove columns
							cols: length? columns
							rows: (length? buffer) / cols
							;	emit query results
							either html [emit-HTML][emit-ASCII]
							print ["^/" rows "row(s) selected in" time "seconds"]
						]
					][
						switch/default first statement [
							delete	[print [buffer "row(s) deleted in" time "seconds"]]
							update	[print [buffer "row(s) updated in" time "seconds"]]
							rows	[print [buffer "row(s)"]]
						][
							print form buffer
						]
					]
				][
					error: disarm error
					print switch/default error/id [
						no-value	["Unknown command"]
						expect-arg	["Syntax error"]
						message		[form error/arg1]
					][
						reform [error/type error/id]
					]
				]
			]
		]
	]
]