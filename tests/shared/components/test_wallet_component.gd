extends GutTest

var wallet: WalletComponent


func before_each() -> void:
	wallet = WalletComponent.new()
	add_child_autofree(wallet)


func test_add_and_spend() -> void:
	wallet.add(120)
	assert_true(wallet.spend(100))
	assert_eq(wallet.credits, 20)


func test_cannot_overspend() -> void:
	wallet.add(50)
	assert_false(wallet.spend(51))
	assert_eq(wallet.credits, 50, "nothing taken on a failed purchase")


func test_negative_amounts_are_ignored() -> void:
	wallet.add(-30)
	assert_eq(wallet.credits, 0)
	assert_false(wallet.spend(-10))
	wallet.set_credits(-5)
	assert_eq(wallet.credits, 0)


func test_set_and_replicate() -> void:
	wallet.set_credits(300)
	assert_eq(wallet.credits, 300)
	wallet.apply_replicated(42)
	assert_eq(wallet.credits, 42)
	assert_true(wallet.can_afford(42))
	assert_false(wallet.can_afford(43))
