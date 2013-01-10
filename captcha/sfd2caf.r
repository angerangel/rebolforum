REBOL []

list: make block! 256
ws: charset " ^/^M^-"
digit: charset ".-0123456789"
num: [some digit]
space: [any [#" "]]
max-chars: cnt: 0

selected: charset [#"0" - #"9" #"A" - #"Z" #"a" - #"z" "@ΰηθικω*"]

if not file: request-file/only/title/filter "Choose a font" "Convert" "*.sfd" [quit]
sfd-file: read file
;makedir/deep join %fonts/ file

get-glyph: func [id [integer!]][
	foreach [a b c d] list [
		if b/2 = id [return d]
	]
	make error! "glyph not found!"
]

print "converting..."

if not parse/all sfd-file [
	to "StartChar:"
	some [
		err:
		"StartChar: " copy value to newline (
			append list value
			outline: none
			if zero? remainder cnt: cnt + 1 100 [prin [cnt #"."]]
		)
		| "Encoding: " copy value to newline (append/only list to block! value)
		| "Width: " copy value to newline (append list to integer! value) 
		| "Fore" any [ws] (
			append/only list outline: reduce ['shape cursor: make block! 16]
		)
			some [
				some [
					copy coord [space num space num] (
						coord: to-pair load coord
						coord/y: negate coord/y
						append cursor coord
					)
				]
				space [
					"m"	(insert cursor 'move)
					| "l" (insert cursor 'line)
					| "c" (insert cursor 'curve)
				] (
					;new-line cursor true
					cursor: tail cursor
				) thru #"^/"
				| "EndSplineSet"
			]
		| "Flags:" to newline
		| "GlyphClass:" to newline
		| "Ref:" copy value to newline (
			if not outline [append/only list outline: make block! 16]
			append outline value
		)
		| "Refer:" to newline
		| "HStem:" to newline
		| "VStem:" to newline
		| "DStem:" to newline
		| "VWidth:" to newline
		| "AnchorPoint:" to newline
		| "Comment:" to newline
		| "Colour:" to newline
		| "CounterMasks:" to newline 
		| "Image:" thru "EndImage"
		| "TtfInstrs:" thru "EndTtf"
		| "EndChars" to end
		| "EndChar" (if not outline [append/only list []])
		| "EndSplineFont"
		| skip
	]
][
	print ["stopped parsing at:" copy/part err 80]
]

;new-line/skip list true 4
print "^/resolving references..."

dive: func [glyph /local pos ref trans blk][
	if pos: find glyph string! [
		until [
			parse/all pos/1 [copy ref [to "N" | to "S"] skip copy trans to end]
			ref: first to block! ref
			remove pos			
			insert pos reduce ['push blk: copy/deep dive get-glyph ref]
			if [1 0 0 1 0 0] <> trans: to block! trans [
				trans/6: negate trans/6
				insert blk reduce ['matrix trans]
			]		
			not pos: find pos string!
		]
	]
	glyph
]
cnt: 0
foreach [name codes width glyph] list [
	if zero? remainder cnt: cnt + 1 100 [prin [cnt #"."]]

	dive glyph
]

comment {

.caf file format:

HEADER: size=892 (223*4)
offset(int32)
...

GLYPH:
size(int32), glyph-data(size)

}

sel: make block! 255  ; [ascii [glyph]...]

foreach [name codes width glyph] list [
	if codes/2 > 255 [break]
	if all [
		positive? codes/2
		find selected codes/2
	][
		repend sel [codes/2 glyph]
	]
]

caf-head: make binary! 892
insert/dup caf-head #{00} 892
caf: make binary! 40'000

for c 32 255 1 [
	if glyph: select sel c [
		glyph: mold/flat glyph
		pos: (index? tail caf) - 1		
		repend caf [
			debase/base to-hex length? glyph 16
			glyph
		]
		change at caf-head ((c - 32) * 4) + 1 debase/base to-hex pos 16
	]
]

write/binary replace file ".sfd" ".caf" join caf-head caf
print ""

halt
