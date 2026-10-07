# webrtc-native (nicht eingecheckt)

Godot braucht unter Windows und Linux die offizielle GDExtension
[webrtc-native](https://github.com/godotengine/webrtc-native) fuer WebRTC.
Im Web-Export ist WebRTC eingebaut, dort wird sie nicht gebraucht.

- Version: `1.2.2-stable` (Asset `godot-extension-webrtc_native.zip`)
- Laden: `npm run fetch:webrtc` (prueft SHA-256, kopiert nur Windows- und
  Linux-x86_64-Bibliotheken, `.gdextension` und Lizenzen hierher)
- Lizenz: MIT (`LICENSE.webrtc-native`); gebuendelte Bibliotheken (libdatachannel,
  libjuice, libsrtp, mbedtls, plog, usrsctp) mit eigenen `LICENSE.*`-Dateien
- Pruefen: `Godot --headless --path godot --script res://tools/webrtc_probe.gd`
  gibt `WEBRTC_OK` oder `WEBRTC_MISSING` aus
