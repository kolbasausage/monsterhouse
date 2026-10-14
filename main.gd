extends Control

const CLICKS_PER_FOOD := 10
const HEAT_TIME := 4.5
const FEED_AMOUNT := 8.0
const WRONG_FOOD_PENALTY := 5.0
const DRAIN_PER_SEC := 1.5
const NIGHT_LENGTH := 240.0 #second from 12 am to 6 am
const DEMAND_EXPIRE := 8.0

var bar := 50.0
var chop_clicks := 0
var cold_food := 0
var hot_food := 0
var heating := false
var wants_hot := false
var demand_left := 0.0
var next_demand_in := 12.0
var elapsed := 0.0
var game_over := false

var bar_ui := ProgressBar.new()
var info_label := Label.new()


func _ready() -> void:
	bar_ui.position = Vector2(300, 20)
	bar_ui.custom_minimum_size = Vector2(550, 30)
	add_child(bar_ui)
	info_label.position = Vector2(300, 70)
	add_child(info_label)
	make_button("CHOP", Vector2(850, 300), on_chop)
	make_button("HEAT", Vector2(600, 200), on_heat)
	make_button("SERVE COLD", Vector2(300, 550), on_serve_cold)
	make_button("SERVE HOT", Vector2(500, 550), on_serve_hot)


func make_button(text: String, pos: Vector2, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(150, 60)
	b.pressed.connect(action)
	add_child(b)


func _process(delta: float) -> void:
	if game_over:
		return
	elapsed += delta
	bar -= DRAIN_PER_SEC * delta
	update_demand(delta)
	check_end()
	update_ui()


func update_demand(delta: float) -> void:
	if wants_hot:
		demand_left -= delta
		if demand_left <= 0.0:
			wants_hot = false
		return
	next_demand_in -= delta
	if next_demand_in <= 0.0:
		wants_hot = true
		demand_left = DEMAND_EXPIRE
		next_demand_in = randf_range(10.0, 20.0)


func check_end() -> void:
	if bar <= 0.0:
		end_game("YOU GOT EATEN")
	elif bar >= 100.0:
		end_game("THE MONSTER GOT TOO STRONG")
	elif elapsed >= NIGHT_LENGTH:
		end_game("6 AM. YOU SURVIVED")


func end_game(message: String) -> void:
	game_over = true
	info_label.text = message + "\n(press Enter to restart)"


func update_ui() -> void:
	bar_ui.value = bar
	var hour := int(elapsed / NIGHT_LENGTH * 6.0)
	var shown_hour := 12 if hour == 0 else hour
	var status := ""
	if wants_hot:
		status += "  !! WANTS HOT !!"
	if heating:
		status += "  (heating...)"
	info_label.text = "%d AM | chop %d/%d | cold %d | hot %d%s" % [
		shown_hour, chop_clicks, CLICKS_PER_FOOD, cold_food, hot_food, status]


func on_chop() -> void:
	if game_over:
		return
	chop_clicks += 1
	if chop_clicks >= CLICKS_PER_FOOD:
		chop_clicks = 0
		cold_food += 1


func on_heat() -> void:
	if game_over or heating or cold_food < 1:
		return
	cold_food -= 1
	heating = true
	await get_tree().create_timer(HEAT_TIME).timeout
	heating = false
	hot_food += 1


func on_serve_cold() -> void:
	if game_over or cold_food < 1:
		return
	cold_food -= 1
	if wants_hot:
		bar -= WRONG_FOOD_PENALTY
	else:
		bar += FEED_AMOUNT


func on_serve_hot() -> void:
	if game_over or hot_food < 1:
		return
	hot_food -= 1
	wants_hot = false
	bar += FEED_AMOUNT


func _unhandled_input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
