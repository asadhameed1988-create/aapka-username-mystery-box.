extends Node
## Autoload "Ads": WHEN ads may appear. The ad SDK itself sits behind a provider
## object, so the game runs the same with no SDK, with the test provider, or
## with AdMob (docs/monetization/AdmobProvider.gd.txt, installed by the owner).
##
## Rules built in here:
## - Interstitials only BETWEEN boxes (after the result screen), never during a puzzle,
##   never in the first FREE_BOXES boxes, at most one per MIN_GAP_SEC, every N boxes
##   (N comes from the server config, default 4). None after the "remove ads" purchase.
## - Rewarded ads are always optional and give REWARD_HINTS hint tokens (in-game only),
##   at most MAX_REWARDED_PER_DAY times a day.

signal reward_granted(amount: int)

const PROVIDER_PATH := "res://scripts/monetize/AdmobProvider.gd"
const REWARD_HINTS := 3
const MIN_GAP_SEC := 120
const FREE_BOXES := 3
const MAX_REWARDED_PER_DAY := 5

var _provider = null
var _boxes_since_ad: int = 0
var _last_interstitial_msec: int = -MIN_GAP_SEC * 1000


func _ready() -> void:
	if ResourceLoader.exists(PROVIDER_PATH):
		var script = load(PROVIDER_PATH)
		if script != null:
			set_provider(script.new())


## A provider is a Node with: setup(), is_interstitial_ready(), show_interstitial(on_closed: Callable),
## is_rewarded_ready(), show_rewarded(on_reward: Callable, on_closed: Callable).
func set_provider(provider) -> void:
	if _provider != null:
		_provider.queue_free()
	_provider = provider
	if _provider != null:
		add_child(_provider)
		_provider.setup()


func has_provider() -> bool:
	return _provider != null


func ads_removed() -> bool:
	return bool((GameState.data["purchases"] as Dictionary).get("remove_ads", false))


func _config() -> Dictionary:
	return GameState.data["online"].get("config", {})


func enabled() -> bool:
	return _provider != null and bool(_config().get("ads_enabled", true))


func box_finished() -> void:
	_boxes_since_ad += 1


func should_show_interstitial() -> bool:
	if not enabled() or ads_removed():
		return false
	if int(GameState.data["stats"]["solved"]) <= FREE_BOXES:
		return false
	if _boxes_since_ad < maxi(1, int(_config().get("interstitial_every_n_boxes", 4))):
		return false
	if Time.get_ticks_msec() - _last_interstitial_msec < MIN_GAP_SEC * 1000:
		return false
	return bool(_provider.is_interstitial_ready())


## Call when the player leaves a result screen. `after` always runs, with or without an ad.
func maybe_interstitial(after: Callable) -> void:
	if not should_show_interstitial():
		after.call()
		return
	_boxes_since_ad = 0
	_last_interstitial_msec = Time.get_ticks_msec()
	Analytics.track("ad_impression", {"kind": "interstitial"})
	_provider.show_interstitial(after)


func rewarded_left_today() -> int:
	var state: Dictionary = GameState.data["ads"]
	if str(state.get("rewarded_day", "")) != Missions.today_key():
		return MAX_REWARDED_PER_DAY
	return maxi(0, MAX_REWARDED_PER_DAY - int(state.get("rewarded_count", 0)))


func rewarded_available() -> bool:
	return enabled() and rewarded_left_today() > 0 and bool(_provider.is_rewarded_ready())


## Optional ad chosen by the player. The reward is hint tokens only: never money, never transferable.
func show_rewarded() -> void:
	if not rewarded_available():
		return
	Analytics.track("ad_impression", {"kind": "rewarded"})
	_provider.show_rewarded(_on_reward, func() -> void: pass)


func _on_reward() -> void:
	var state: Dictionary = GameState.data["ads"]
	if str(state.get("rewarded_day", "")) != Missions.today_key():
		state["rewarded_day"] = Missions.today_key()
		state["rewarded_count"] = 0
	state["rewarded_count"] = int(state["rewarded_count"]) + 1
	Missions.add_hints(REWARD_HINTS)
	GameState.save_game()
	Analytics.track("ad_reward", {"hints": REWARD_HINTS})
	reward_granted.emit(REWARD_HINTS)
