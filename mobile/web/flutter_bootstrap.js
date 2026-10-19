{{flutter_js}}
{{flutter_build_config}}

// Le service worker généré par Flutter est obsolète (il se désinscrit lui-même) :
// on ne l'enregistre plus. Le cache hors ligne est géré par naatal_sw.js (voir index.html).
_flutter.loader.load();
