extends Control

const CLICKS_PER_FOOD := 10
const HEAT_TIME := 4.5
const FEED_AMOUNT := 8.0
const WRONG_FOOD_PENALTY := 5.0
const NIGHT_LENGTH := 240.0 # real seconds from 12am to 6am
const CHOP_DELAY := 0.15 # delay so players can see animations

const DRAIN_START := 1.2
const DRAIN_END := 2.2
const FIRST_DEMAND_IN := 12.0 # seconds until the first hot demand
const DEMAND_GAP_START := 16.0 # seconds between demands at 12am
const DEMAND_GAP_END := 8.0 # seconds between demands at 6am

var bar := 50.0
var chop_clicks := 0
var cold_food := 0
var hot_food := 0
var heating := false
var wants_hot := false
var next_demand_in := FIRST_DEMAND_IN
var elapsed := 0.0
var game_over := false

@onready var chop_bar: Range = $chop_bar
@onready var hunger_bar: Range = $hunger_bar
@onready var serve_cold: BaseButton = $serve_cold
@onready var serve_hot: BaseButton = $serve_hot
@onready var heat: BaseButton = $heat
@onready var chop: BaseButton = $chop
@onready var info_label: Label = $info_label
@onready var monster: AnimatedSprite2D = $monster
@onready var chef: AnimatedSprite2D = $chef
@onready var microwave: AnimatedSprite2D = $microwave


func _ready() -> void:
	chop_bar.max_value = CLICKS_PER_FOOD
	hunger_bar.min_value = 0
	hunger_bar.max_value = 100
	chop.pressed.connect(on_chop)
	heat.pressed.connect(on_heat)
	serve_cold.pressed.connect(on_serve_cold)
	serve_hot.pressed.connect(on_serve_hot)
	monster.sprite_frames.set_animation_loop("idle", true)
	monster.sprite_frames.set_animation_loop("eating", false)
	chef.sprite_frames.set_animation_loop("idle", true)
	chef.sprite_frames.set_animation_loop("chopping", false)
	microwave.sprite_frames.set_animation_loop("idle", true)
	microwave.sprite_frames.set_animation_loop("turned_on", true)
	monster.animation_finished.connect(func(): monster.play("idle"))
	chef.animation_finished.connect(func(): chef.play("idle"))
	monster.play("idle")
	chef.play("idle")
	microwave.play("idle")


func _process(delta: float) -> void:
	if game_over:
		return
	elapsed += delta
	var progress := clampf(elapsed / NIGHT_LENGTH, 0.0, 1.0)
	bar -= lerpf(DRAIN_START, DRAIN_END, progress) * delta
	update_demand(delta, progress)
	check_end()
	if game_over:
		return
	update_ui()


func update_demand(delta: float, progress: float) -> void:
	if wants_hot:
		return
	next_demand_in -= delta
	if next_demand_in <= 0.0:
		wants_hot = true
		next_demand_in = lerpf(DEMAND_GAP_START, DEMAND_GAP_END, progress)


func check_end() -> void:
	if bar <= 0.0:
		end_game("YOU GOT EATEN")
	elif bar >= 100.0:
		end_game("THE MONSTER GOT TOO STRONG")
	elif elapsed >= NIGHT_LENGTH:
		end_game("6 AM. YOU SURVIVED. GO TO SLEEP")


func end_game(message: String) -> void:
	game_over = true
	hunger_bar.value = clampf(bar, 0.0, 100.0)
	info_label.text = message + "\n(press Enter to restart)"


func update_ui() -> void:
	hunger_bar.value = bar
	chop_bar.value = chop_clicks
	monster.modulate = Color(1.0, 0.55, 0.4) if wants_hot else Color.WHITE
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
	chop.disabled = true
	get_tree().create_timer(CHOP_DELAY).timeout.connect(func(): chop.disabled = false)
	restart_anim(chef, "chopping")
	chop_clicks += 1
	if chop_clicks >= CLICKS_PER_FOOD:
		chop_clicks = 0
		cold_food += 1


func on_heat() -> void:
	if game_over or heating or cold_food < 1:
		return
	cold_food -= 1
	heating = true
	microwave.play("turned_on")
	await get_tree().create_timer(HEAT_TIME).timeout
	heating = false
	hot_food += 1
	microwave.play("idle")


func on_serve_cold() -> void:
	if game_over or cold_food < 1:
		return
	cold_food -= 1
	restart_anim(monster, "eating")
	if wants_hot:
		bar -= WRONG_FOOD_PENALTY
	else:
		bar += FEED_AMOUNT


func on_serve_hot() -> void:
	if game_over or hot_food < 1:
		return
	hot_food -= 1
	wants_hot = false
	restart_anim(monster, "eating")
	bar += FEED_AMOUNT


func restart_anim(sprite: AnimatedSprite2D, anim: String) -> void:
	sprite.stop()
	sprite.play(anim)


func _unhandled_input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
