extends Node2D
var model
var font: Font
func _draw():
	if model==null: return
	for b in model.bricks:
		if b.hp<=0 or not b.get("bounty",false): continue
		var rect: Rect2 = model.brick_rect(b)
		var caption = "%d/%d" % [maxi(0,ceili(b.hp)),ceili(b.max_hp)]
		var width = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_rect(Rect2(rect.get_center()+Vector2(-width/2-5,-11),Vector2(width+10,23)),Color(0.03,0.04,0.06,0.85))
		draw_string(font,rect.get_center()+Vector2(-width/2,6),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
		var bar=Rect2(rect.position+Vector2(7,rect.size.y-10),Vector2(rect.size.x-14,5))
		draw_rect(bar,Color("18121c"))
		draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(float(b.hp)/b.max_hp,0,1),5)),Color("ffe28a"))
