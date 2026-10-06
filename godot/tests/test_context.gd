extends RefCounted

# Sammelt Fehler einer Testsuite. root ist ein Node fuer Szenen-Tests.

var failures: Array = []
var current_suite := ""
var root: Node = null
var checks := 0

func expect(cond: bool, message: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [current_suite, message])
