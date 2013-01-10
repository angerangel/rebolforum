REBOL [title: "REBOL Forum Functions"]

addresponse: func [forum-url forum-topicnumber forum-username forum-message] [ 
    my-post: rejoin [
        {function=addresponse}
        {&topicnumber=} forum-topicnumber 
        {&name=} forum-username 
        {&message=} forum-message
    ]
    read/custom forum-url reduce ['post my-post]
]

addnew: func [forum-url forum-username forum-topic forum-message] [ 
    my-post: rejoin [
        {function=addnew}
        {&name=} forum-username
        {&topic=} forum-topic 
        {&message=} forum-message
    ]
    read/custom forum-url reduce ['post my-post]
]
