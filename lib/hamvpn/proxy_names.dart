/// Понятные имена серверов в списке выбора страны.
///
/// Из подписки Marzban приходят имена вида «🇩🇪 Германия (login)» и
/// «🇩🇪 Германия · XHTTP (login)» — второй вариант это запасной способ
/// подключения к той же стране. Служебные группы движка (автовыбор, ручной
/// выбор) получают русские названия.
String hamProxyName(String raw, {String type = ''}) {
  final t = type.toLowerCase();
  final lower = raw.toLowerCase().trim();
  if (t == 'urltest' || lower.contains('auto') || lower.contains('lowest')) {
    return '⚡ Автовыбор — самый быстрый';
  }
  if (t == 'selector' || lower == 'select' || lower == 'proxy' || lower.contains('§ select')) {
    return 'Выбор сервера';
  }
  var name = raw.replaceAll('§', '').trim();
  // «· XHTTP» → «· 2»: второй, запасной канал к той же стране
  name = name.replaceAll(RegExp(r'\s*[·•\-–]\s*XHTTP', caseSensitive: false), ' · 2');
  name = name.replaceAll(RegExp(r'\s*XHTTP\s*', caseSensitive: false), ' · 2 ');
  return name.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

/// Подпись под именем: вместо технического «vless / urltest» — понятный текст.
String hamProxySubtitle({required String type, required bool isGroup, String selected = ''}) {
  final t = type.toLowerCase();
  if (isGroup) {
    final s = selected.trim();
    if (t == 'urltest') return s.isEmpty ? 'Сам выбирает самый быстрый сервер' : 'Сейчас: ${hamProxyName(s)}';
    return s.isEmpty ? '' : 'Сейчас: ${hamProxyName(s)}';
  }
  return 'Сервер';
}
