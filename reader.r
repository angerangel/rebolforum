REBOL [title: "REBOL Forum Reader"]

screen: system/view/screen-face/size - 100x100
topics: copy []  database: copy []

update: does [
    topics: copy []
    database: copy load to-file request-file/title/file
        "Load Messages:" "" %rebolforum.txt
    foreach topic database [
        append topics first topic
    ]
    t1/data: copy topics
    show t1
    a1/text: copy {}
    show a1
]

view center-face layout [
    size (screen)
    across
    t1: text-list ((as-pair (round/to (screen/1 * .25) 1) (screen/2)) - 23x73) data topics [
        messages: copy ""
        foreach [message name time] (at pick database t1/cnt 2) [
            append messages rejoin [
                message newline newline name "  " time newline newline
                "---------------------------------------"  newline newline
            ]
        ]
        a1/text: copy messages
        show a1
    ]
    a1: area wrap ((as-pair (round/to (screen/1 * .75) 1) (screen/2)) - 23x73)
    return
    btn "Download Recent Messages" [
        write to-file request-file/save/title/file
            "Save Messages to File:" "" %rebolforum.txt
            read http://rebolforum.com/bb.db
    ]
    btn "Download Archived Messages" [
        write to-file request-file/save/title/file
            "Save Messages to File:" "" %rebolforum-archive.txt
            read http://rebolforum.com/archive.db
    ]
    btn "Read Downloaded Messages" [update]  
]