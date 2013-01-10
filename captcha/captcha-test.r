REBOL [
	title: "Captcha Tester"
]

do %captcha.r
captcha/set-fonts-path %fonts/

solved: total: 0

view center-face layout [
	style lab lbl no-wrap font [style: none]
	style draw-box box white effect [draw []]
	size 500x200
	origin 0x0
	across
	pad 0x5
	lbl "Font:" 35
	pad -10x2
	fname: lab 100 "" font [size: 9]
	lbl "Level:" 50 right
	flevel: drop-down rows 5
		"1 - very easy"
		"2 - easy"
		"3 - medium"
		"4 - hard"
		"5 - very hard"
	return 
	pad 10x0
	paper: draw-box 300x120
	pad 0x-30
	butGen: btn "Generate" [
		captcha/level: to-integer copy/part get-face flevel 1
		clear paper/effect/draw
		append paper/effect/draw captcha/generate/source
		show paper
		set-face fname form copy/part file: second split-path captcha/glyphs find file #"."
		reset-face lblRes
		focus edInput
	]
	;intxt: field "Test" 100
	at butGen/offset + 0x40 
	lbl "Try:" 
	edInput: field 100 [
		if not captcha/text [exit]
		either captcha/answer? edInput/text captcha/text [
			lblRes/font/color: green / 2
			set-face lblRes "OK"
			solved: solved + 1
		][
			lblRes/font/color: red / 1.5
			set-face lblRes captcha/text
		]
		total: total + 1
		set-face lblSolved rejoin [
			(to-integer (solved / total * 1E4)) / 100 "% - "
			solved " / " total
		]
		show lblRes
		clear-face edInput
		captcha/text: none	
	]
	return
	at butGen/offset + 0x80 lblRes: lbl 140 center font-size 24 edge [size: 1x1 color: black]
	at butGen/offset + 0x120
	lbl "Solved:" lblSolved: lab 100
]
