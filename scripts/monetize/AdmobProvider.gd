extends Node
## AdMob provider for Ads.gd, for the plugin  godot-sdk-integrations/godot-admob  (v7.0, MIT),
## installed at res://addons/AdmobPlugin/ .
##
## Every name used here (node properties, methods, signals) was read from the plugin's own source
## (addon/src/main/Admob.gd, commit 83d7144 of 2026-11-03). It has NOT been run on a phone yet.
## The plugin is reached only by name, so this file is harmless when the plugin is not installed
## or the game is not running on Android: the provider then reports "no ad ready".

const ADMOB_SCRIPT := "res://addons/AdmobPlugin/Admob.gd"

# ---- Fill in after creating the app and ad units in the AdMob console (docs/MONETIZATION.md). ----
# While ADS_REAL is false the plugin uses Google's public TEST ad units, which is what you want
# during testing: clicking your own real ads can get an AdMob account suspended.
const ADS_REAL := false
const ADMOB_APP_ID := ""               # ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
const ADMOB_INTERSTITIAL_ID := ""      # ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ
const ADMOB_REWARDED_ID := ""

const CONSENT_REQUIRED := 2            # UserConsent.Status.REQUIRED
const RETRY_SECONDS := 60.0
const WATCHDOG_SECONDS := 120.0        # never leave the game waiting forever for an ad to close

var _admob: Node = null
var _initialized: bool = false
var _after_interstitial: Callable
var _on_reward: Callable
var _after_rewarded: Callable
var _showing: String = ""


func setup() -> void:
	if not OS.has_feature("android") or not ResourceLoader.exists(ADMOB_SCRIPT):
		return
	# A Play release never shows Google's TEST ads: until the real ids are filled in,
	# release builds simply run without ads. Debug (test) builds show test ads.
	if not OS.is_debug_build() and not (ADS_REAL and ADMOB_APP_ID != "" and ADMOB_INTERSTITIAL_ID != "" and ADMOB_REWARDED_ID != ""):
		return
	var script: Script = load(ADMOB_SCRIPT) as Script
	if script == null:
		return
	var node: Node = script.new()
	# The Admob node reads its ids in its own _ready(), so set them before add_child().
	node.set("is_real", ADS_REAL and ADMOB_INTERSTITIAL_ID != "" and ADMOB_REWARDED_ID != "")
	node.set("android_real_application_id", ADMOB_APP_ID)
	node.set("android_real_interstitial_id", ADMOB_INTERSTITIAL_ID)
	node.set("android_real_rewarded_id", ADMOB_REWARDED_ID)
	node.connect("initialization_completed", _on_initialized)
	node.connect("consent_info_updated", _on_consent_info_updated)
	node.connect("consent_info_update_failed", _on_consent_finished)
	node.connect("consent_form_loaded", _on_consent_form_loaded)
	node.connect("consent_form_failed_to_load", _on_consent_finished)
	node.connect("consent_form_dismissed", _on_consent_finished)
	node.connect("interstitial_ad_failed_to_load", _on_load_failed.bind("interstitial"))
	node.connect("interstitial_ad_dismissed_full_screen_content", _on_interstitial_closed)
	node.connect("interstitial_ad_failed_to_show_full_screen_content", _on_interstitial_show_failed)
	node.connect("rewarded_ad_failed_to_load", _on_load_failed.bind("rewarded"))
	node.connect("rewarded_ad_user_earned_reward", _on_reward_earned)
	node.connect("rewarded_ad_dismissed_full_screen_content", _on_rewarded_closed)
	node.connect("rewarded_ad_failed_to_show_full_screen_content", _on_rewarded_show_failed)
	add_child(node)
	_admob = node
	node.call("initialize")


func _on_initialized(_status) -> void:
	_initialized = true
	# Google's consent platform first (required for players in regions with consent laws).
	_admob.call("update_consent_info")


func _on_consent_info_updated() -> void:
	var consent = _admob.call("get_consent_status")
	if consent != null and int(consent.get("status")) == CONSENT_REQUIRED:
		if bool(_admob.call("is_consent_form_available")):
			_admob.call("show_consent_form")
		else:
			_admob.call("load_consent_form")
		return
	_load_ads()


func _on_consent_form_loaded() -> void:
	_admob.call("show_consent_form")


func _on_consent_finished(_error = null) -> void:
	_load_ads()


func _load_ads() -> void:
	if not Ads.ads_removed():
		_admob.call("load_interstitial_ad")
	_admob.call("load_rewarded_ad")


func _on_load_failed(_info, _error, kind: String) -> void:
	await get_tree().create_timer(RETRY_SECONDS).timeout
	if _admob == null:
		return
	if kind == "interstitial":
		if not Ads.ads_removed():
			_admob.call("load_interstitial_ad")
	else:
		_admob.call("load_rewarded_ad")


func _watchdog(kind: String) -> void:
	await get_tree().create_timer(WATCHDOG_SECONDS).timeout
	if _showing == kind:
		if kind == "interstitial":
			_finish_interstitial()
		else:
			_finish_rewarded()


# ------------------------------------------------------------ interstitial

func is_interstitial_ready() -> bool:
	return _admob != null and _initialized and bool(_admob.call("is_interstitial_ad_loaded"))


func show_interstitial(on_closed: Callable) -> void:
	_after_interstitial = on_closed
	_showing = "interstitial"
	_watchdog("interstitial")
	_admob.call("show_interstitial_ad")


func _finish_interstitial() -> void:
	if _showing != "interstitial":
		return
	_showing = ""
	if _after_interstitial.is_valid():
		_after_interstitial.call()
	if not Ads.ads_removed():
		_admob.call("load_interstitial_ad")


func _on_interstitial_closed(_info) -> void:
	_finish_interstitial()


func _on_interstitial_show_failed(_info, _error) -> void:
	_finish_interstitial()


# ---------------------------------------------------------------- rewarded

func is_rewarded_ready() -> bool:
	return _admob != null and _initialized and bool(_admob.call("is_rewarded_ad_loaded"))


func show_rewarded(on_reward: Callable, on_closed: Callable) -> void:
	_on_reward = on_reward
	_after_rewarded = on_closed
	_showing = "rewarded"
	_watchdog("rewarded")
	_admob.call("show_rewarded_ad")


func _on_reward_earned(_info, _reward) -> void:
	if _on_reward.is_valid():
		_on_reward.call()


func _finish_rewarded() -> void:
	if _showing != "rewarded":
		return
	_showing = ""
	if _after_rewarded.is_valid():
		_after_rewarded.call()
	_admob.call("load_rewarded_ad")


func _on_rewarded_closed(_info) -> void:
	_finish_rewarded()


func _on_rewarded_show_failed(_info, _error) -> void:
	_finish_rewarded()
