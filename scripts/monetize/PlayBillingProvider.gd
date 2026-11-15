extends Node
## Google Play Billing provider for Store.gd, for the plugin
## godot-sdk-integrations/godot-google-play-billing  (3.x, MIT), installed at
## res://addons/GodotGooglePlayBilling/ .
##
## Method, signal and dictionary key names were read from the plugin's own source and docs
## (BillingClient.gd and Utils.kt, master of 2026-07-26). It has NOT been run on a phone yet.
## The plugin is reached only by name, so this file is harmless when it is not installed.

const BILLING_SCRIPT := "res://addons/GodotGooglePlayBilling/BillingClient.gd"
const BILLING_SINGLETON := "GodotGooglePlayBilling"
const OK_CODE := 0          # BillingClient.BillingResponseCode.OK
const INAPP := 0            # BillingClient.ProductType.INAPP
const PURCHASED := 1        # BillingClient.PurchaseState.PURCHASED
const TOKENS_KEPT := 50

var _store = null
var _client: Node = null
var _prices: Dictionary = {}


func setup(store) -> void:
	_store = store
	if not Engine.has_singleton(BILLING_SINGLETON) or not ResourceLoader.exists(BILLING_SCRIPT):
		return
	var script: Script = load(BILLING_SCRIPT) as Script
	if script == null:
		return
	var client: Node = script.new()
	client.connect("connected", _on_connected)
	client.connect("query_product_details_response", _on_product_details)
	client.connect("query_purchases_response", _on_purchases)
	client.connect("on_purchase_updated", _on_purchases)
	add_child(client)
	_client = client
	client.call("start_connection")


func is_ready() -> bool:
	return _client != null and bool(_client.call("is_ready"))


## Localised price text from Google Play ("" until the store has answered).
func price(product_id: String) -> String:
	return str(_prices.get(product_id, ""))


func _on_connected() -> void:
	# Product details must be queried before purchase() works; the purchases query restores
	# "remove_ads" on a new phone and finishes interrupted purchases.
	_client.call("query_product_details", PackedStringArray(_store.PRODUCTS.keys()), INAPP)
	_client.call("query_purchases", INAPP)


func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != OK_CODE:
		return
	for product in response.get("product_details", []):
		var offers = product.get("one_time_purchase_offer_details_list")
		if typeof(offers) == TYPE_ARRAY and not (offers as Array).is_empty():
			_prices[str(product.get("product_id", ""))] = str(offers[0].get("formatted_price", ""))
	_store.prices_changed.emit()


func buy(product_id: String) -> void:
	if not is_ready():
		_store.failed(product_id)
		return
	var result = _client.call("purchase", product_id)
	if typeof(result) == TYPE_DICTIONARY and int(result.get("response_code", -1)) != OK_CODE:
		_store.failed(product_id)


func _on_purchases(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != OK_CODE:
		return
	for purchase in response.get("purchases", []):
		process_purchase(purchase)


## Grants one completed purchase exactly once, then acknowledges or consumes it.
func process_purchase(purchase: Dictionary) -> void:
	if int(purchase.get("purchase_state", 0)) != PURCHASED:
		return                                   # pending payments are granted later
	var token: String = str(purchase.get("purchase_token", ""))
	for product_id in Array(purchase.get("product_ids", [])):
		var info: Dictionary = _store.PRODUCTS.get(str(product_id), {})
		if info.is_empty():
			continue
		if bool(info["consumable"]):
			var granted: Array = GameState.data["purchases"]["granted_tokens"]
			if token != "" and not granted.has(token):
				granted.append(token)
				while granted.size() > TOKENS_KEPT:
					granted.pop_front()
				_store.grant(str(product_id))
			if _client != null:
				_client.call("consume_purchase", token)
		else:
			_store.grant(str(product_id))        # Store.grant ignores a purchase it already recorded
			if _client != null and not bool(purchase.get("is_acknowledged", false)):
				_client.call("acknowledge_purchase", token)     # Google refunds unacknowledged purchases
