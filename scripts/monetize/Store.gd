extends Node
## Autoload "Store": in-app purchases. Like Ads, the billing SDK sits behind a
## provider (docs/monetization/PlayBillingProvider.gd.txt). With no provider the
## shop simply says that purchases are not available in this build.

signal purchase_finished(product_id: String, ok: bool)
signal prices_changed

const PROVIDER_PATH := "res://scripts/monetize/PlayBillingProvider.gd"
const MAX_HINTS_WITH_PACK := 99
## Product ids must match the ids created in Google Play Console.
const PRODUCTS := {
	"remove_ads": {"consumable": false, "title": "store_remove_ads"},
}

var _provider = null


func _ready() -> void:
	if ResourceLoader.exists(PROVIDER_PATH):
		var script = load(PROVIDER_PATH)
		if script != null:
			set_provider(script.new())


## A provider is a Node with: setup(store), buy(product_id). It calls store.grant(product_id)
## for every confirmed purchase (also for purchases restored at start) and store.failed(product_id).
func set_provider(provider) -> void:
	if _provider != null:
		_provider.queue_free()
	_provider = provider
	if _provider != null:
		add_child(_provider)
		_provider.setup(self)


func available() -> bool:
	if _provider == null:
		return false
	if _provider.has_method("is_ready"):
		return bool(_provider.is_ready())
	return true


## Price text from the store for a product ("" when unknown).
func price(product_id: String) -> String:
	if _provider != null and _provider.has_method("price"):
		return str(_provider.price(product_id))
	return ""


func owned(product_id: String) -> bool:
	return bool((GameState.data["purchases"] as Dictionary).get(product_id, false))


func buy(product_id: String) -> void:
	if _provider == null or not PRODUCTS.has(product_id):
		purchase_finished.emit(product_id, false)
		return
	_provider.buy(product_id)


## Called by the provider once Google Play has confirmed the purchase.
func grant(product_id: String) -> void:
	if not PRODUCTS.has(product_id):
		return
	var product: Dictionary = PRODUCTS[product_id]
	if bool(product["consumable"]):
		var inv: Dictionary = GameState.data["inventory"]
		inv["hints"] = mini(MAX_HINTS_WITH_PACK, int(inv["hints"]) + int(product.get("hints", 0)))
	else:
		if owned(product_id):
			return                      # restored purchase that is already recorded
		GameState.data["purchases"][product_id] = true
	GameState.save_game()
	Analytics.track("purchase", {"product": product_id})
	purchase_finished.emit(product_id, true)


func failed(product_id: String) -> void:
	purchase_finished.emit(product_id, false)
