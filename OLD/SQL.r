REBOL [
	Title:		"RebDB SQL wrapper"
	Owner:		"Ashley G. Trüter"
	Version:	2.0.2
	Date:		14-Jan-2006
	Purpose:	"End-user SQL wrapper."
	History: {
		2.0.0	Initial release
		2.0.1	Minor fixes and enhancements
		2.0.2	Renamed Needs block to Scripts
	}
	Scripts: [%db.r %db-client.r]
]

foreach script system/script/header/Scripts [do script]

if exists? %login.sql [
	client/run %login.sql
]

either any [none? client/address tcp://: <> copy/part client/address 7][
	;	none or tcp://127.0.0.1:1000
	forever [client/execute ask "SQL> "]
][
	;	tcp://:1000
	listen client/address
]