class_name Autostart
extends RefCounted
## Windows "start with the computer" registration.
##
## DropClock is meant to behave like an appliance rather than an app you launch,
## so this writes a per-user Run entry. Per-user (HKCU) on purpose: it needs no
## administrator rights, and it only ever touches this account.
##
## Only meaningful for an exported .exe. Running from the editor would register
## the Godot binary itself, so is_supported() refuses in that case.

const RUN_KEY := "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
const RUN_KEY_LONG := "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
const VALUE_NAME := "DropClock"
const IMPORT_FILE := "user://autostart.reg"


static func is_supported() -> bool:
	return OS.get_name() == "Windows" and not OS.has_feature("editor")


## Why autostart is unavailable, for the overlay to show. "" when it is fine.
static func unsupported_reason() -> String:
	if OS.get_name() != "Windows":
		return "Windows only"
	if OS.has_feature("editor"):
		return "export a build first"
	return ""


static func is_enabled() -> bool:
	if not is_supported():
		return false
	var output := []
	return OS.execute("reg", ["query", RUN_KEY, "/v", VALUE_NAME], output, true) == 0


## Returns true if the registry now matches what was asked for.
static func set_enabled(enabled: bool) -> bool:
	if not is_supported():
		push_warning("DropClock: autostart unavailable (%s)" % unsupported_reason())
		return false
	return _write_entry() if enabled else _delete_entry()


## Registers the executable.
##
## Written through a .reg file rather than `reg add /v ... /d ...`, because the
## /d argument passes through the C runtime's command-line parser on the way in,
## which eats the quotes the value needs. Measured: the entry came out as
## C:/path/DropClock.exe, unquoted and with forward slashes. Unquoted is fine
## until the path contains a space, at which point Windows guesses where the
## executable name ends and the entry silently stops working. A .reg file states
## the exact bytes, so nothing is left to guess.
static func _write_entry() -> bool:
	var exe := OS.get_executable_path().replace("/", "\\")

	# .reg escaping: backslashes doubled, quotes backslash-escaped. The value
	# itself is the quoted path, so a path with spaces stays one token.
	var escaped := exe.replace("\\", "\\\\").replace("\"", "\\\"")
	var lines := "Windows Registry Editor Version 5.00\r\n\r\n[%s]\r\n\"%s\"=\"\\\"%s\\\"\"\r\n" % [
		RUN_KEY_LONG, VALUE_NAME, escaped,
	]

	var file := FileAccess.open(IMPORT_FILE, FileAccess.WRITE)
	if file == null:
		push_error("DropClock: could not write %s (error %d)" % [IMPORT_FILE, FileAccess.get_open_error()])
		return false
	# reg.exe wants UTF-16LE with a byte order mark. Godot writes UTF-8, so the
	# bytes are assembled by hand; this also keeps non-ASCII user paths intact.
	var bytes := PackedByteArray([0xFF, 0xFE])
	bytes.append_array(lines.to_utf16_buffer())
	file.store_buffer(bytes)
	file.close()

	var real_path := ProjectSettings.globalize_path(IMPORT_FILE)
	var output := []
	var code := OS.execute("reg", ["import", real_path], output, true)
	DirAccess.remove_absolute(real_path)

	if code != 0:
		push_error("DropClock: autostart enable failed, reg exited %d: %s"
			% [code, "\n".join(PackedStringArray(output))])
		return false
	return true


static func _delete_entry() -> bool:
	var output := []
	var code := OS.execute("reg", ["delete", RUN_KEY, "/v", VALUE_NAME, "/f"], output, true)
	if code != 0:
		push_error("DropClock: autostart disable failed, reg exited %d: %s"
			% [code, "\n".join(PackedStringArray(output))])
		return false
	return true


## The exact command Windows will run at login, or "" if not registered.
## Used to check the entry still points at this build after the exe is moved.
static func registered_command() -> String:
	if not is_supported():
		return ""
	var output := []
	if OS.execute("reg", ["query", RUN_KEY, "/v", VALUE_NAME], output, true) != 0:
		return ""
	for line in output:
		var text := str(line)
		var marker := text.find("REG_SZ")
		if marker != -1:
			return text.substr(marker + 6).strip_edges()
	return ""
