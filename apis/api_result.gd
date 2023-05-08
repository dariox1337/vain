class_name APIResult extends Resource

enum {OK, STREAM, STREAM_ENDED, ERROR}

var status: int
var message: String

func _init(stat: int, msg: String):
	status = stat
	message = msg
