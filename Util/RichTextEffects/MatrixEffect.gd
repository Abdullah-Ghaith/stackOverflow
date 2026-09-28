@tool
extends RichTextEffect
class_name RichTextMatrix

var bbcode = "matrix"

func get_text_server():
	return TextServerManager.get_primary_interface()

func _process_custom_fx(char_fx):
	var clear_time  = char_fx.env.get("clean", 2.0)
	var dirty_time  = char_fx.env.get("dirty", 1.0)
	var text_span   = char_fx.env.get("span", 50)

	var char_offset = char_fx.range.x / float(text_span)
	var local_time  = char_fx.elapsed_time - char_offset

	# Still scrambling
	if local_time < dirty_time:
		var matrix_time = local_time / dirty_time
		var value = get_text_server().font_get_char_from_glyph_index(char_fx.font, 1, char_fx.glyph_index)
		var scrambled = int(matrix_time * (126 - 65))
		scrambled %= (126 - 65)
		scrambled += 65
		char_fx.glyph_index = get_text_server().font_get_glyph_index(char_fx.font, 1, scrambled, 0)
		return true

	# Done — stay clean
	return true
