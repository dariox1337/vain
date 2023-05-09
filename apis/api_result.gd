class_name APIResult extends Resource

enum {OK, STREAM, STREAM_ENDED, ERROR}

var status: int
var msg_uid: String
var message: String

func _init(stat: int, uid: String, msg: String):
	status = stat
	msg_uid = uid
	message = msg
