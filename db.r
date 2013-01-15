REBOL [
	Title:		"RebDB server"
	Owner:		"Ashley G. Trüter"
	Version:	2.0.3
	Date:		13-Apr-2007
	Purpose:	"Server-side DB functions."
	History: {
		2.0.0	2nd generation release based on native REBOL datatypes
		2.0.1	Added automatic log recovery
				Minor fixes and enhancements
		2.0.2	Replaced "if not" syntax with "unless"
				Added new-line support to facilitate external reading/editing of .dat files
				Now checks for core > 2.6.0
				Replaced DISTINCT's use of unique/skip with slower but correct mezz code
		2.0.3	Replaced complex db-commit save code with write mold/only/all
				open-table now does a new-line off
				Added /joins refinement to db-select
				Added /replaces refinement to db-select
				Updated 'sql function to handle strings and : args
				Optimized intersect tests
				Added /only to non-rowid search criteria to handle block! values
	}
]

db: context [

	;	----------------------------------------
	;		Default values
	;	----------------------------------------

	base-dir:		what-dir			; base directory for table (%.ctl %.dat %.log) files
	lines?:			true				; store rows with line-breaks?
	buffer:			make block! 4096	; stores values returned from lookup and select
	plan:			make block! 8 * 4	; used by explain to trace execution path
	tables:			make block! 32 * 2	; table name / definition block pairs
	reserved-words:	[					; 'rowid must appear first as 'sql relies on this
		rowid avg by count desc distinct explain from group having header into joins max min on order replaces set std sum table to values where with
	]

	;	----------------------------------------
	;		Helper functions
	;	----------------------------------------

	between: func [val lo hi][all [val >= lo val <= hi]]

	to-type: function [string [string!]][s][
		either attempt [s: load string][s][string]
	]

	set 'soundex function [
		"Phonetic representation of a string."	; derived from soundex.r
		string [any-string!]
	][
		code val
	][
		string: unique uppercase form trim string
		if empty? string [return none]
		code: make string! 4
		insert code copy/part string 1
		;	convert chars 2-4
		foreach char next string [
			parse form char [
				[
					  [["B" | "F" | "P" | "V"]							(val: "1")]
					| [["C" | "G" | "J" | "K" | "Q" | "S" | "X" | "Z"]	(val: "2")]
					| [["D" | "T"]										(val: "3")]
					| [["L"]											(val: "4")]
					| [["M" | "N"]										(val: "5")]
					| [["R"]											(val: "6")]
				]
				(insert tail code val)
			]
			if 3 = length? code [break]	; stop after reaching 3rd char
		]
		code
	]

	;	----------------------------------------
	;		Aggregation functions
	;	----------------------------------------

	set 'sum-of function [
		block [block!]
	][
		total
	][
		total: 0
		foreach val block [total: total + val]
		total
	]

	set 'avg-of func [
		block [block!]
	][
		(sum-of block) / length? block
	]

	set 'std-of function [
		"Standard Deviation."	; derived from http://home.europa.com/~dwhiting/satyre/dwmath1.zip
		vals [block!]
	][
		total mbar div
	][
		if 2 > length? vals [return 0]
		total: 0
		mbar: (sum-of vals) / length? vals
		div: (length? vals) - 1
		foreach val vals [
			total: total + (((val - mbar) ** 2) / div)
		]
		square-root total
	]

	;	----------------------------------------
	;		Explain and Log functions
	;	----------------------------------------

	explain?: false

	explain-seq: none

	explain-time: none

	explain-plan: func [step [string!] type [string! word!]][
		if explain? [
			insert tail plan reduce [explain-seq step type now/time/precise - explain-time]
			explain-seq: explain-seq + 1
			explain-time: now/time/precise
		]
	]

	log?: true

	log-seq: 0

	log: func [table [word!] statement [string!]][
		if log? [
			write/append tables/:table/log-file reduce [
				"; "
				log-seq: log-seq + 1
				" "
				now "^/" replace/all statement "^/" " " "^/"
			]
		]
	]

	;	----------------------------------------
	;		Low-level table handling functions
	;	----------------------------------------

	check-table: function [
		table [word!]
		columns [block!]
	][
		data
	][
		;	has at least one column name been provided?
		if empty? columns [
			close-table table
			to-error "At least one column name must be specified"
		]
		;	is table name a reserved word?
		if find reserved-words table [
			close-table table
			to-error "Table name is a reserved word"
		]
		;	are any column names reserved words?
		unless empty? intersect columns reserved-words [
			close-table table
			to-error "Column name is a reserved word"
		]
		;	are column names unique?
		if (length? columns) <> length? unique columns [
			close-table table
			to-error "Column names must be unique"
		]
	]

	close-table: func [
		table [word!]
	][
		;	is table loaded?
		if find tables table [
			tables/:table/data: none
			remove/part find tables table 2
			recycle
			explain-plan "Close" table
		]
	]

	sort-table: func [
		table [word!]
	][
		;	is table sorted?
		unless tables/:table/sorted? [
			sort/skip/all tables/:table/data tables/:table/cols
			tables/:table/sorted?: true
			explain-plan "Sort" table
		]
	]

	open-table: function [
		table [word!]
		/no-clear
	][
		ctl-file dat-file log-file
	][
		unless no-clear [buffer: head buffer clear buffer]
		clear plan
		;	is table already open?
		if find tables table [
			tables/:table/accessed: now
			tables/:table/accesses: tables/:table/accesses + 1
			return
		]
		if any [
			not exists? ctl-file: join base-dir/:table %.ctl
			not exists? dat-file: join base-dir/:table %.dat
		][
			to-error reform [table "not found"]
		]
		if all [
			exists? log-file: join base-dir/:table %.log
			log?
		][
			to-error reform [table "has an open log file"]
		]
		;	load control file
		insert tail tables reduce [table load ctl-file]
		insert tail tables/:table reduce [
			'cols length? tables/:table/columns
			'rows 0
			'offsets copy []
			'data new-line/all load/all dat-file off
			'ctl-file ctl-file
			'dat-file dat-file
			'log-file log-file
			'sorted? true
			'loaded now
			'accessed now
			'accesses 1
			'dirty? false
		]
		check-table table tables/:table/columns
		;	verify row count
		tables/:table/rows: (length? tables/:table/data) / tables/:table/cols
		unless integer? tables/:table/rows [
			to-error "Invalid row count"
		]
		;	populate offsets
		repeat offset tables/:table/cols [
			insert tail tables/:table/offsets reduce [
				pick tables/:table/columns offset
				offset
			]
		]
		recycle
		explain-plan "Open" table
	]

	;	----------------------------------------
	;		Search functions
	;	----------------------------------------

	to-index: func [rowid [integer!] cols [integer!]][
		rowid - 1 * cols + 1
	]

	to-rowid: func [index [integer!] cols [integer!]][
		index - 1 / cols + 1
	]

	binary-search: function [
		"Returns rowid of first key match."	; derived from binary-search.r
		data [block!]
		key [any-type!]
		cols [integer!]
		hi [integer!]
	][
		lo mid length
	][
		lo: 1
		mid: to integer! hi + lo / 2
		either block? key [
			length: length? key
			while [hi >= lo][
				if key = copy/part at data to-index mid cols length [return mid]
				either key > copy/part at data to-index mid cols length [lo: mid + 1][hi: mid - 1]
				mid: to integer! hi + lo / 2
			]
		][
			while [hi >= lo][
				if key = pick data to-index mid cols [return mid]
				either key > pick data to-index mid cols [lo: mid + 1][hi: mid - 1]
				mid: to integer! hi + lo / 2
			]
		]
		none
	]

	key-search: function [
		"Returns rows that match key(s)."
		table [word!]
		columns [block!]
		key [any-type!]
	][
		blk data lo hi
	][
		sort-table table
		data: tables/:table/data
		;	find first and last match
		if lo: find/skip data key tables/:table/cols [
			hi: find/skip/last data key tables/:table/cols
			;	select *?
			either columns = tables/:table/columns [
				insert buffer copy/part lo (index? hi) - (index? lo) + tables/:table/cols
				explain-plan "Search" "Key *"
			][
				blk: copy []
				foreach column columns [
					insert tail blk either column = 'rowid [
						copy [insert tail buffer rowid]
					][
						compose [
							insert/only tail buffer pick skip data rowid - 1 * (tables/:table/cols) (tables/:table/offsets/:column)
						]
					]
				]
				lo: to-rowid index? lo tables/:table/cols
				hi: to-rowid index? hi tables/:table/cols
				for rowid lo hi 1 blk
				explain-plan "Search" "Key"
			]
		]
	]

	rowid-search: function [
		"Returns rows that meet predicate."
		table [word!]
		columns [block!]
		predicate [block!]
	][
		blk data rowid
	][
		;	buffer handler
		either columns = tables/:table/columns [
			blk: compose [
				insert tail buffer copy/part skip data rowid - 1 * (tables/:table/cols) (tables/:table/cols)
			]
		][
			blk: copy []
			foreach column columns [
				insert tail blk either column = 'rowid [
					copy [insert tail buffer rowid]
				][
					compose [
						insert/only tail buffer pick skip data rowid - 1 * (tables/:table/cols) (tables/:table/offsets/:column)
					]
				]
			]
		]
		;	execute
		predicate: replace copy predicate 'last tables/:table/rows
		data: tables/:table/data
		switch/default second predicate [
			=		[rowid: third predicate do blk]
			<		[repeat rowid (third predicate) - 1 blk]
			>		[for rowid (third predicate) + 1 tables/:table/rows 1 blk]
			between	[for rowid (third predicate) (last predicate) 1 blk]
		][
			repeat rowid tables/:table/rows compose/deep [if (predicate) [(blk)]]
		]
	]

	equality-search: function [
		"Returns rows that match an offset key."
		table [word!]
		columns [block!]
		key [any-type!]
		offset
	][
		blk data file
	][
		;	buffer handler
		either columns = tables/:table/columns [
			blk: compose [insert tail buffer copy/part skip file pos - (offset) (tables/:table/cols)]
		][
			blk: copy []
			foreach column columns [
				insert tail blk either column = 'rowid [
					compose [insert tail buffer to-rowid pos - (offset) + 1 (tables/:table/cols)]
				][
					compose [insert/only tail buffer pick file pos - (offset) + (tables/:table/offsets/:column)]
				]
			]
		]
		;	execute
		data: at tables/:table/data offset
		file: tables/:table/data
		while [pos: find/only/skip data key tables/:table/cols] compose [
			pos: index? pos
			(blk)
			data: at head data pos + (tables/:table/cols)
		]
	]

	search: function [
		"Passes predicate to one of four search routines: rowid, key, equality or linear."
		table [word!]
		columns [block!]
		predicate [any-type!]
	][
		offset rowid
	][
		either block? predicate [
			either 'rowid = first predicate [
				rowid-search table columns predicate
				explain-plan "Search" "Rowid"
			][
				;	do we have a simple col = val type expression?
				either all [
					3 = length? predicate
					'= = second predicate
					not none? offset: select tables/:table/offsets first predicate
				][
					;	column other than first?
					either offset > 1 [
						;	equality-search uses find/only as it expects a single key
						equality-search table columns third predicate offset
						explain-plan "Search" "Equality"
					][
						;	key-search can't use find/only as it uses a block to determine number of keys
						key-search table columns either any-block? third predicate [
							reduce [third predicate]
						][
							third predicate
						]
					]
				][
					;	do we have a block of conditions or a block of values?
					either any [
						not empty? intersect predicate tables/:table/columns
						find [all any] first predicate
					][
						do compose/deep [
							do has [rowid][
								rowid: 1
								foreach [(tables/:table/columns)] tables/:table/data [
									if (predicate) [insert tail buffer reduce [(columns)]]
									(either find columns 'rowid [copy [rowid: rowid + 1]][copy []])
								]
							]
						]
						explain-plan "Search" "Linear"
					][
						key-search table columns predicate
					]
				]
			]
		][
			key-search table columns predicate
		]
	]

	fetch: function [
		"Fetches all rows of selected column(s)."
		table [word!]
		columns [block!]
	][
		data seq pos
	][
		;	format buffer
		insert/dup buffer none tables/:table/rows * length? columns
		;	populate buffer
		seq: 0
		foreach column columns compose/deep [
			seq: seq + 1
			pos: seq - (length? columns)
			either column = 'rowid [
				repeat rowid (tables/:table/rows) [
					poke buffer pos: pos + (length? columns) rowid
				]
			][
				data: at tables/:table/data tables/:table/offsets/:column
				loop (tables/:table/rows) [
					poke buffer pos: pos + (length? columns) first data
					data: skip data (tables/:table/cols)
				]
			]
			explain-plan "Fetch" column
		]
	]

	;	Informational
	;		db-desc			Information about the columns of a table.
	;		db-describe		Information about the columns of a table.
	;		db-rows			Number of rows in table.
	;		db-show			Database statistics.
	;		db-table?		Returns true if table exists.
	;		db-tables		Information about currently open tables.
	;	Table Management
	;		db-close		Closes a table with no changes pending.
	;		db-commit		Saves a table with changes pending.
	;		db-create		Creates a table.
	;		db-drop			Drops a table.
	;		db-rollback		Closes a table with changes pending.
	;	Row Retrieval
	;		db-lookup		Returns first row that matches a key.
	;		db-select		Returns columns and rows from a table.
	;	Row Management
	;		db-delete		Deletes row(s) from a table.
	;		db-insert		Appends a row of values to a table.
	;		db-truncate		Deletes all rows from a table.
	;		db-update		Updates row(s) in a table.
	;	Pre-Processor
	;		explain			Executes statement and returns plan.
	;		listen			Listens for incoming requests.
	;		sql				Transforms a SQL statement into a db function call.

	;	----------------------------------------
	;		Informational
	;	----------------------------------------

	set [db-desc db-describe] func [
		"Information about the columns of a table."
		'table [word!]
		/header "Append header block"
	][
		open-table table
		foreach column tables/:table/columns [
			insert tail buffer reduce [
				column
				type? pick tables/:table/data tables/:table/offsets/:column
			]
		]
		if header [
			insert/only tail buffer reduce [table 'Column 'Type]
		]
		copy buffer
	]

	set 'db-rows func [
		"Number of rows in table."
		'table [word!]
	][
		open-table table
		tables/:table/rows
	]

	set 'db-show func [
		"Database statistics."
		/header "Append header block"
	][
		insert clear buffer reduce [
			"Host"		system/network/host
			"Address"	system/network/host-address
			"Memory"	system/stats
			"Tables"	(length? tables) / 2
		]
		if header [
			insert/only tail buffer copy [Database Property Value]
		]
		copy buffer
	]

	set 'db-table? func [
		"Returns true if table exists."
		'table [word!]
	][
		either any [find tables table exists? join base-dir/:table %.ctl][true][false]
	]

	set 'db-tables func [
		"Information about currently open tables."
		/header "Append header block"
	][
		clear buffer
		foreach [table blk] tables [
			insert tail buffer reduce [
				table
				tables/:table/cols
				tables/:table/rows
				tables/:table/sorted?
				to-date first parse form tables/:table/loaded "+"
				to-date first parse form tables/:table/accessed "+"
				tables/:table/accesses
				tables/:table/dirty?
			]
		]
		if all [header not empty? buffer][
			insert/only tail buffer copy [Tables Table Cols Rows Sorted? Loaded Accessed Hits Dirty?]
		]
		copy buffer
	]

	;	----------------------------------------
	;		Table Management
	;	----------------------------------------

	set 'db-close func [
		"Closes a table with no changes pending."
		'table [word!] "Table, * for all"
	][
		foreach table either table = '* [extract tables 2][to-block table][
			if all [find tables table not tables/:table/dirty?][
				close-table table
			]
		]
		true
	]

	set 'db-commit func [
		"Saves a table with changes pending."
		'table [word!] "Table, * for all"
	][
		foreach table either table = '* [extract tables 2][to-block table][
			if all [find tables table tables/:table/dirty?][
				sort-table table
				either lines? [
					new-line/skip tables/:table/data on tables/:table/cols	; add new-lines
					new-line tables/:table/data off							; remove first new-line
					write tables/:table/dat-file mold/only/all tables/:table/data
					new-line/all tables/:table/data off						; remove all new-lines
				][
					write tables/:table/dat-file mold/only/all tables/:table/data
				]
				recycle
				tables/:table/dirty?: false
				delete tables/:table/log-file
			]
		]
		true
	]

	set 'db-create func [
		"Creates a table."
		'table [word!]
		columns [block!] "Column names"
	][
		if any [
			find tables table
			exists? join base-dir/:table %.ctl
			exists? join base-dir/:table %.dat
		][
			to-error "Table already exists"
		]
		check-table table columns
		;	write files
		save join base-dir/:table %.ctl compose/deep [Columns [(columns)]]
		write join base-dir/:table %.dat ""
		true
	]

	set 'db-drop func [
		"Drops a table."
		'table [word!]
	][
		unless exists? join base-dir/:table %.ctl [to-error "No such table"]
		close-table table
		delete join base-dir/:table %.ctl
		delete join base-dir/:table %.dat
		attempt [delete join base-dir/:table %.log]
		true
	]

	set 'db-rollback func [
		"Closes a table with changes pending."
		'table [word!] "Table, * for all"
	][
		foreach table either table = '* [extract tables 2][to-block table][
			if all [find tables table tables/:table/dirty?][
				delete tables/:table/log-file
				close-table table
			]
		]
		true
	]

	;	----------------------------------------
	;		Row Retrieval
	;	----------------------------------------

	set 'db-lookup func [
		"Returns first row that matches a key."
		'table [word!]
		key [any-type!] "Value or block of values"
		/rowid "Return rowid"
		/header "Append header block"
	][
		open-table table
		sort-table table
		;	binary search
		if key: binary-search tables/:table/data key tables/:table/cols tables/:table/rows [
			insert buffer either rowid [key][
				copy/part at tables/:table/data to-index key tables/:table/cols tables/:table/cols
			]
			if header [
				insert/only tail buffer either rowid [reduce [table 'Rowid]][compose [(table) (tables/:table/columns)]]
			]
		]
		copy buffer
	]

	fast-lookup: func [
		"Minimal version of db-lookup."
		'table [word!]
		key [any-type!] "Value or block of values"
	][
		;	binary search
		either key: binary-search tables/:table/data key tables/:table/cols tables/:table/rows [
			copy/part at tables/:table/data to-index key tables/:table/cols tables/:table/cols
		][none]
	]

	set 'db-select function [
		"Returns columns and rows from a table."
		'columns [word! block!] "Column(s) to fetch, * for all"
		'table [word!]
		/where predicate [any-type!] "Search condition(s)"
		/joins
			query-block [block!] "Details query"
			'on-columns [word! block!] "Master column(s) to join on"
		/replaces
			'lookup-columns [word! block!] "Column(s) to replace"
			'lookup-tables [word! block!] "Lookup table(s)"
		/order 'by-columns [word! block!] "Column(s) to sort by"
		/desc "Reverse sort"
		/distinct "Sorted unique rows"
		/count "Count aggregate"
		/min "Minimum aggregate"
		/max "Maximum aggregate"
		/sum "Summation aggregate"
		/avg "Average aggregate"
		/std "Standard deviation aggregate"
		/group 'grp-columns [word! block!] "Column(s) to group by"
		/having grp-predicate [block!] "Aggregate condition(s)"
		/header "Append header block"
	][
		cols
		blk
		agg
		tally
		result
		key
		master-on-cols
		query-plan
		query-cols
		query-table
		query-columns
	][
		if all [desc not order][to-error "desc requires order by"]
		if all [having not group][to-error "having requires group by"]
		if all [group not any [count min max sum avg std]][to-error "group by requires an aggregate"]
		if all [distinct group][to-error "cannot use distinct in conjunction with group by"]
		if all [joins group][to-error "cannot use joins with group by"]
		open-table table
		;	ensure columns is a block of valid column names
		either columns = '* [
			;	copy required to preserve column names from aggregate change
			columns: copy tables/:table/columns
		][
			;	are all columns in table
			if (columns: to-block columns) <> intersect columns union [Rowid] tables/:table/columns [
				to-error "Invalid select column"
			]
		]
		;	number of cols
		cols: length? columns
		;	are joins on columns valid?
		either joins [
			if (on-columns: to-block on-columns) <> intersect on-columns tables/:table/columns [
				to-error "Invalid joins on column"
			]
			master-on-cols: (length? on-columns) - length? intersect on-columns columns
			columns: union columns on-columns
			loop length? on-columns [
				change on-columns index? find columns first on-columns
				on-columns: next on-columns
			]
			on-columns: head on-columns
			;	pre-proccess sub-query
			query-block: sql/no-execute query-block
			open-table/no-clear query-table: third to-block query-block
			sort-table query-table
			query-columns: either '* = second to-block query-block [copy tables/:query-table/columns] [to-block second to-block query-block]	; to-block required for single column
			;	are all columns in table
			if query-columns <> intersect query-columns tables/:query-table/columns [
				to-error "Invalid details select column"
			]
			query-cols: cols + length? query-columns
			cols: cols + master-on-cols
		][
			query-columns: copy []
			query-cols: cols
		]
		;	replaces
		if replaces [
			if (length? lookup-columns: to-block lookup-columns) <> length? lookup-tables: to-block lookup-tables [
				to-error "Invalid number of replace column(s) or lookup table(s)"
			]
			if lookup-columns <> intersect lookup-columns union columns query-columns [
				to-error "Invalid lookup column"
			]
			foreach lookup-table lookup-tables [
				unless db-table? :lookup-table [to-error "Invalid lookup table"]
			]
		]
		;	are aggregates valid?
		agg: either any [count min max sum avg std][
			either query-cols = 1 [
				if group [to-error "cannot group by result column"]
			][
				unless group [to-error "missing group by clause"]
				grp-columns: to-block grp-columns
				if (length? grp-columns) <> (query-cols - 1) [
					to-error "Invalid number of group by columns"
				]
				if (sort copy grp-columns) <> sort copy/part union columns query-columns query-cols - 1 [
					to-error "Invalid group by column"
				]
				loop length? grp-columns [
					change grp-columns index? find union columns query-columns first grp-columns
					grp-columns: next grp-columns
				]
				grp-columns: head grp-columns
			]
			true
		][
			false
		]
		;	are sort columns valid?
		if order [
			by-columns: to-block by-columns
			if by-columns <> intersect by-columns union columns query-columns [
				to-error "Invalid order by column"
			]
			if query-cols > 1 [
				loop length? by-columns [
					change by-columns index? find union columns query-columns first by-columns
					by-columns: next by-columns
				]
				by-columns: head by-columns
			]
		]
		;	execute query
		either where [
			search table columns predicate
		][
			;	select * from table?
			either columns = tables/:table/columns [
				insert buffer tables/:table/data
				explain-plan "Fetch" "*"
			][
				fetch table columns
			]
		]
		unless empty? buffer [
			;	JOINS
			if joins [
				blk: copy []
				query-plan: copy plan
				;	add each row
				do compose/deep [
					foreach [(columns)] copy buffer [
						query-table: copy query-block
						foreach offset on-columns [
							replace/all query-table join ":" pick [(columns)] offset pick reduce [(columns)] offset
						]
						do query-table
						unless empty? buffer [
							;	insert master details
							while [not tail? buffer] [
								insert tail blk copy/part reduce [(columns)] (cols - master-on-cols)
								insert tail blk copy/part buffer (length? query-columns)
								buffer: skip buffer (length? query-columns)
								insert tail query-plan plan
							]
							buffer: head buffer
						]
					]
				]
				insert clear buffer blk
				insert clear plan query-plan
				blk: none
				loop master-on-cols [remove back tail columns]	; remove columns not in original selection
				insert tail columns query-columns
				cols: length? columns
			]
			;	REPLACES
			if replaces [
				foreach lookup-table lookup-tables [
					open-table/no-clear :lookup-table
					buffer: at buffer index? find columns first lookup-columns
					remove lookup-columns
					while [not tail? buffer] [
						if first buffer [	; skip none!
							if result: binary-search tables/:lookup-table/data first buffer tables/:lookup-table/cols tables/:lookup-table/rows [
								result: first skip tables/:lookup-table/data to-index result tables/:lookup-table/cols
							]
							change buffer result
						]
						buffer: skip buffer cols
					]
					buffer: head buffer
				]
			]
			;	DISTINCT
			if distinct [
				;	bug in unique/skip
				;blk: either cols = 1 [unique buffer][unique/skip buffer cols]
				either cols = 1 [
					blk: unique buffer
				][
					blk: copy []
					sort/skip/all buffer cols
					result: none
					while [not tail? buffer][
						if result <> copy/part buffer cols [
							insert tail blk result: copy/part buffer cols
						]
						buffer: skip buffer cols
					]
					buffer: head buffer
				]
				insert clear buffer blk
				explain-plan "Distinct" reform [cols "Column(s)"]
			]
			;	AGGREGATE
			if agg [
				agg: switch true compose [
					(count)	[change back tail columns 'Count copy [length? tally]]
					(min)	[change back tail columns 'Min copy [first minimum-of tally]]
					(max)	[change back tail columns 'Max copy [first maximum-of tally]]
					(sum)	[change back tail columns 'Sum copy [sum-of tally]]
					(avg)	[change back tail columns 'Avg copy [avg-of tally]]
					(std)	[change back tail columns 'Std copy [std-of tally]]
				]
				either cols = 1 [
					tally: buffer
					result: do agg
					insert clear buffer result
				][
					;	can't use reduce as we need to "unblock" the result from agg
					agg: either having [
						compose [
							set [count min max sum avg std] (agg)
							if (grp-predicate) [
								insert tail buffer result
								insert tail buffer count
							]
						]
					][
						compose [
							insert tail buffer result
							insert tail buffer (agg)
						]
					]
					;	sort buffer in grouped column order
					blk: copy sort/skip/compare buffer cols grp-columns
					;	tally rows
					tally: copy []
					result: copy/part blk (cols - 1)
					clear buffer
					do compose/deep [
						do has [count min max sum avg std] [
							loop (length? blk) / cols [
								if result <> copy/part blk (cols - 1) [
									;	tally grouped values
									(agg)
									clear tally
									result: copy/part blk (cols - 1)
								]
								insert tail tally pick blk (cols)
								blk: skip blk (cols)
							]
							(agg)
						]
					]
					;	release memory
					blk: tally: result: none
				]
				explain-plan "Aggregate" reform [cols "Column(s)"]
			]
			;	ORDER BY
			if order [
				;	single-column sort?
				either cols = 1 [
					either desc [sort/reverse buffer][sort buffer]
					explain-plan "Sort" "One Column"
				][
					;	all-column sort is over 50% faster than a block! compare
					either all [cols = length? by-columns by-columns = sort copy by-columns][
						either desc [sort/skip/all/reverse buffer cols][sort/skip/all buffer cols]
						explain-plan "Sort" "All Columns"
					][
						;	integer! compare is over 50% faster than block! compare
						if 1 = length? by-columns [by-columns: first by-columns]
						either desc [sort/skip/compare/reverse buffer cols by-columns][sort/skip/compare buffer cols by-columns]
						explain-plan "Sort" "Default"
					]
				]
			]
		]
		if all [count empty? buffer cols = 1][
			insert buffer 0
		]
		if all [header not empty? buffer][
			insert/only tail buffer compose [(table) (columns)]
		]
		recycle
		copy buffer
	]

	;	----------------------------------------
	;		Row Management
	;	----------------------------------------

	set 'db-delete function [
		"Deletes row(s) from a table."
		'table [word!]
		predicate [any-type!] "Value or block of values"
		/where "Treat predicate as a block of search conditions"
	][
		data
	][
		open-table table
		;	find rows to act upon
		either where [
			search table [rowid] predicate
		][
			db-lookup/rowid :table predicate
		]
		if empty? buffer [return 0]
		;	log query
		log table mold/only/all either where [
			reduce ['delete 'from table 'where predicate]
		][
			reduce ['delete 'from table predicate]
		]
		data: tables/:table/data
		;	serialised rowids?
		either (length? buffer) = ((last buffer) - (first buffer) + 1) [
			remove/part at data to-index first buffer tables/:table/cols tables/:table/cols * length? buffer
		][
			;	process rowids starting from tail
			foreach rowid head reverse buffer compose [
				;	remove row from data file
				remove/part at data to-index rowid (tables/:table/cols) (tables/:table/cols)
			]
		]
		tables/:table/rows: tables/:table/rows - length? buffer
		tables/:table/dirty?: true
		recycle
		length? buffer
	]

	set 'db-insert func [
		"Appends a row of values to a table."
		'table [word!] "The table argument"
		values [block!] "Values to insert"
		/header "Append header block"
	][
		open-table table
		if tables/:table/cols <> length? values [to-error "Invalid number of values"]
		insert buffer values
		repeat pos tables/:table/cols [
			if buffer/:pos = 'next [
				poke buffer pos either tables/:table/rows > 0 [
					1 + pick tail tables/:table/data pos - tables/:table/cols - 1
				][1]
			]
		]
		;	is buffer > last row
		if all [
			tables/:table/sorted?
			not zero? tables/:table/rows
			buffer < copy skip tables/:table/data (length? tables/:table/data) - tables/:table/cols
		][
			tables/:table/sorted?: false
		]
		log table mold/only/all reduce ['insert 'into table 'values values]
		insert tail tables/:table/data buffer
		tables/:table/rows: tables/:table/rows + 1
		tables/:table/dirty?: true
		if header [insert/only tail buffer compose [(table) (tables/:table/columns)]]
		copy buffer
	]

	set 'db-truncate function [
		"Deletes all rows from a table."
		'table [word!]
	][
		rows
	][
		open-table table
		rows: tables/:table/rows
		log table mold/only/all reduce ['truncate table]
		clear tables/:table/data
		tables/:table/rows: 0
		tables/:table/sorted?: true
		tables/:table/dirty?: true
		recycle
		rows
	]

	set 'db-update function [
		"Updates row(s) in a table."
		'table [word!]
		'columns [word! block!] "Columns to set"
		values [any-type!] "Values to use"
		predicate [any-type!] "Value or block of values"
		/where "Treat predicate as a block of search conditions"
	][
		data
		offsets
		blk
		exp-columns
	][
		open-table table
		columns: to-block columns	; to-block creates a block of word!
		if columns <> intersect columns tables/:table/columns [
			to-error "Invalid or duplicate column"
		]
		values: compose [(values)]	; compose ensures string! does not become word!
		exp-columns: intersect values tables/:table/columns	; find columns in TO clause
		if all [empty? exp-columns (length? columns) <> length? values][
			to-error "Each column must be assigned a value"
		]
		;	find rowids to act upon
		either where [
			search table [rowid] predicate
		][
			db-lookup/rowid :table predicate
		]
		if empty? buffer [return 0]
		;	log query
		log table mold/only/all either where [
			reduce ['update table 'set columns 'to values 'where predicate]
		][
			reduce ['update table 'set columns 'to values predicate]
		]
		;	calculate column offsets
		offsets: copy []
		foreach column columns [
			insert tail offsets tables/:table/offsets/:column
		]
		data: tables/:table/data
		;	Are there expressions in the TO clause
		either empty? exp-columns [
			foreach rowid buffer compose [
				data: at head data to-index rowid (tables/:table/cols)
				repeat pos (length? columns) [
					poke data offsets/:pos values/:pos
				]
			]
		][
			blk: copy []
			foreach column exp-columns [
				insert tail blk compose [pick data (tables/:table/offsets/:column)]
			]
			do compose/deep [
				do has [(exp-columns)][
					foreach rowid buffer [
						data: at head data to-index rowid (tables/:table/cols)
						;	evaluate expression(s)
						set [(exp-columns)] reduce [(blk)]
						blk: reduce [(values)]
						;	update value(s)
						repeat pos (length? columns) [
							poke data offsets/:pos blk/:pos
						]
					]
				]
			]
		]
		tables/:table/sorted?: false
		tables/:table/dirty?: true
		recycle
		length? buffer
	]

	;	----------------------------------------
	;		Pre-Processor
	;	----------------------------------------

	set 'explain func [
		"Executes statement and returns plan."
		statement [block!]
		/header "Append header block"
	][
		clear plan
		explain?: true
		explain-seq: 1
		explain-time: now/time/precise
		do statement
		explain?: false
		if header [insert/only tail plan [Explain Seq Step Type Time]]
		copy/deep plan	; deep required by SQL client to avoid truncated results
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
		either no-execute [spec] [do spec]
	]

	set 'listen function [
		"Listens for incoming requests."
		address [url!] "Address to listen on (eg. tcp://:1000)"
	][
		port
		request
	][
		either none? attempt [
			address: open/binary/direct/no-wait address
		][
			to-error "Address in use or not available"
		][
			print reform [now/time "Listening on" system/network/host-address]
			forever [
				request: to-string copy port: wait first wait address
				print reform [now/time request]
				request: next find request ":"
				if error? set/any 'request try [do request][request: disarm request]
				print reform [now/time type? request]
				insert port request: compress mold/all request
				close port
				print reform [now/time length? request "bytes"]
			]
		]
	]
]

do db-replay: has [log][
	log: copy []
	;	merge log files
	foreach file read db/base-dir [
		if %.log = suffix? file [
			insert tail log read/lines db/base-dir/:file
		]
	]
	;	anything to replay?
	unless empty? log [
		write/lines db/base-dir/%replay.bak log
		unless value? 'alert [print reform ["Replaying" (length? log) / 2 "change(s)."]]
		;	turn logging off
		db/log?: false
		;	replace comment lines with seq numbers
		repeat i length? log [
			if odd? i [
				poke log i to-integer second parse pick log i none
			]
		]
		;	replay sorted transactions
		foreach [seq statement] sort/skip log 2 [
			unless value? 'alert [print statement]
			sql to-block statement
		]
		;	turn logging on
		db/log-seq: pick tail log -2
		db/log?: true
		log: none
		recycle
		either value? 'alert [alert "Replay completed."] [print "Replay completed."]
	]
]