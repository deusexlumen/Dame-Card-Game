extends RefCounted
class_name PurchaseProvider

# Schnittstelle fuer Kaeufe. Der Shop kennt nur diese Basisklasse.
# ChipProvider ist aktiv. RealMoneyProviderStub haelt den Platz fuer
# einen spaeteren Zahlungsanbieter frei und kauft nie etwas.

func id() -> String:
	return "base"


func label() -> String:
	return ""


func available() -> bool:
	return false


# Ergebnis: {"ok": bool, "reason": String}
func buy(_item: Dictionary, _profile) -> Dictionary:
	return {"ok": false, "reason": "Kein Kaufweg verfügbar"}


class ChipProvider extends PurchaseProvider:
	func id() -> String:
		return "chips"

	func label() -> String:
		return "Chips"

	func available() -> bool:
		return true

	func buy(item: Dictionary, profile) -> Dictionary:
		var price := int(item.get("price", 0))
		if profile.owns(str(item.id)):
			return {"ok": false, "reason": "Schon im Besitz"}
		if int(profile.chips()) < price:
			return {"ok": false, "reason": "Nicht genug Chips"}
		profile.spend(price)
		profile.grant(str(item.id))
		return {"ok": true, "reason": "Gekauft: %s" % str(item.name)}


class RealMoneyProviderStub extends PurchaseProvider:
	func id() -> String:
		return "real_money"

	func label() -> String:
		return "Echtgeld"

	func available() -> bool:
		return false

	func buy(_item: Dictionary, _profile) -> Dictionary:
		return {"ok": false, "reason": "Echtgeld-Käufe sind in dieser Version nicht verfügbar"}
