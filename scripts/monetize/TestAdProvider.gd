extends Node
## Stand-in ad provider for tests and development: no SDK, "ads" finish at once.
## Never shipped as the real provider.

var interstitials_shown: int = 0
var rewarded_shown: int = 0
var ads_ready: bool = true


func setup() -> void:
	pass


func is_interstitial_ready() -> bool:
	return ads_ready


func show_interstitial(on_closed: Callable) -> void:
	interstitials_shown += 1
	on_closed.call()


func is_rewarded_ready() -> bool:
	return ads_ready


func show_rewarded(on_reward: Callable, on_closed: Callable) -> void:
	rewarded_shown += 1
	on_reward.call()
	on_closed.call()
