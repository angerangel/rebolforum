REBOL [
	Title: "Captcha Generator"
	Author: "Nenad Rakocevic/SOFTINNOV"
	Date: 16/07/2007
	Version: 1.0
	License: "BSD"
]

captcha: context [
	random/seed now/time/precise
	
	allowed: exclude 
		charset [#"0" - #"9" #"A" - #"Z" #"a" - #"z" "@"]
		charset "iIl1LoO0"
	
	caf-header-size: 892
	glyphs: port: text: fonts-path: none
	level: 5
	
	random-sign: does [pick [1 -1] 2 = random 2]
	
	set-fonts-path: func [value [file!]][fonts-path: dirize value]
	
	choose-font: has [list][
		list: read join fonts-path %.		
		remove-each file list [%.caf <> suffix? file]
		if empty? list [throw make error! "Captcha ERROR: no CAF font found!"]
		glyphs: join fonts-path pick list random length? list
	]
	
	get-glyph: func [ascii [char!] /local offset size][
		ascii: (to integer! ascii) - 32
		offset: to integer! copy/part at port ascii * 4 + 1 4		
		if zero? offset [return none]
		size: to integer! copy/part at port offset: caf-header-size + offset + 1 4
		load as-string copy/part at port offset + 4 size
	]
	
	create-text: has [out size char][
		out: make string! size: 5 + random 3
		while [size > length? out][
			if find allowed char: 32 + random 223 [
				append out to-char char
			]
		]
		text: out
	]
	
	answer?: func [intext [string!] reference [string!]][
		empty? difference trim/all intext reference
	]
	
	generate: func [/source /local out cnt value img glyph blk][
		choose-font
		create-text
		port: open/seek/binary glyphs
		out: make block! 64
		either level >= 4 [
			repend out [
				'fill-pen
					pick [radial diamond linear diagonal cubic] random 5
					random 299x119
					0 200
					35
					1 1
					;(random [green blue purple red orange yellow brown])					
			]
			append out random [
				100.255.100
				100.100.255
				196.80.196
				255.100.100
				255.200.40
				255.255.80
				239.169.119
			]
		][
			repend out ['fill-pen 255.255.255]
		]
		append out [
			box 0x0 299x119
			scale .04 .04
			line-join round
			line-cap  round
			translate 600x1000
		]	
		cnt: 0
		foreach char text [
			glyph: get-glyph char
			repend out either level >= 3 [
				['pen value: 0.0.0.64 + random 0.0.0.100 'fill-pen value 'line-width 40]
			][
				['pen value: 0.0.0 'fill-pen value 'line-width 30]
			]
			blk: copy [translate]
			append blk either level >= 3 [
				(random 500x1200) + (cnt * 700x0)
			][
				cnt * 800x0 + 0x600
			]
			if level >= 5 [
				repend blk [			
					'skew random-sign * (random pi * 1000) / 1000
					'rotate random-sign * random 30
					'matrix reduce [
						1 
						random-sign * (random 5E3) / 1E4
						random-sign * (random 5E3) / 1E4
						1 0 0
					]
				]
			]
			append blk glyph
			repend out ['push blk]
			if level >= 2 [
				repend out [
					'line-width 10 + random 50
					'fill-pen none
					'push reduce [
						'translate 0x-1000
						'pen value
						'push reduce [
							'spline 10 
								value: random 8000x3200
								value + (random-sign * random 800x800) ;random 8000x3200
								value + (random-sign * random 800x800)  ;random 8000x3200
						]
					]
				]
			]
			cnt: cnt + 1
		]
		append out [
			reset-matrix
			fill-pen none
			line-width 1
			box 0x0 299x119	
		]
		close port
		either source [out][
			save/png img: make binary! 25000 draw 300x120 out
			img
		]
	]
]