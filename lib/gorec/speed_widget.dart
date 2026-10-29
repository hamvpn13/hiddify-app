import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/gorec/gorec_account.dart';
import 'package:hiddify/gorec/gorec_theme.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Замер «без VPN» на самом устройстве: качаем тестовый файл с российского
/// сервера (Selectel, Москва) не дольше [_kTestTime] и не больше [_kTestMaxBytes].
/// Меряем только при выключенном VPN — иначе трафик пошёл бы через VPN.
const _kTestUrl = 'https://speedtest.selectel.ru/100MB';
const _kTestTime = Duration(seconds: 8);
const _kTestMaxBytes = 20 * 1024 * 1024;
const _kAutoEvery = Duration(hours: 1);
const _kPrefMbps = 'ham_local_speed_mbps';
const _kPrefAt = 'ham_local_speed_at';

Future<double?> _measureLocalMbps() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..findProxy = (_) => 'DIRECT';
  try {
    final req = await client.getUrl(Uri.parse(_kTestUrl));
    final resp = await req.close().timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final sw = Stopwatch()..start();
    var bytes = 0;
    final done = Completer<void>();
    late final StreamSubscription<List<int>> sub;
    final timer = Timer(_kTestTime, () {
      if (!done.isCompleted) done.complete();
    });
    sub = resp.listen(
      (chunk) {
        bytes += chunk.length;
        if (bytes >= _kTestMaxBytes && !done.isCompleted) done.complete();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (_) {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await done.future;
    sw.stop();
    timer.cancel();
    await sub.cancel();
    final secs = sw.elapsedMicroseconds / 1e6;
    if (bytes < 256 * 1024 || secs <= 0) return null;
    return bytes * 8 / secs / 1e6;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Окошко под кнопкой на главном экране (Android и Windows):
/// «без VPN» — замер на этом устройстве (когда VPN выключен);
/// «с VPN» — средняя скорость выбранной страны по замерам бота мониторинга за неделю (с сайта).
class GorecSpeedBox extends HookConsumerWidget {
  const GorecSpeedBox({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = useState<Map<String, dynamic>?>(null);
    final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
    final local = useState<double?>(prefs?.getDouble(_kPrefMbps));
    final localAt = useState<DateTime?>(DateTime.tryParse(prefs?.getString(_kPrefAt) ?? ''));
    final measuring = useState(false);
    final status = ref.watch(connectionNotifierProvider).valueOrNull;
    final vpnOff = status?.isDisconnected ?? false;

    Future<void> load() async {
      try {
        data.value = await ref.read(gorecApiProvider).speed();
      } catch (_) {}
    }

    Future<void> measure() async {
      if (measuring.value) return;
      measuring.value = true;
      final v = await _measureLocalMbps();
      // если за время замера VPN включили — результат не считаем
      final stillOff = ref.read(connectionNotifierProvider).valueOrNull?.isDisconnected ?? false;
      if (context.mounted) {
        measuring.value = false;
        if (v != null && stillOff) {
          local.value = v;
          localAt.value = DateTime.now();
          await prefs?.setDouble(_kPrefMbps, v);
          await prefs?.setString(_kPrefAt, DateTime.now().toIso8601String());
        }
      }
    }

    void autoMeasure() {
      final at = localAt.value;
      final off = ref.read(connectionNotifierProvider).valueOrNull?.isDisconnected ?? false;
      if (off && (at == null || DateTime.now().difference(at) > _kAutoEvery)) measure();
    }

    useEffect(() {
      load();
      return null;
    }, const []);
    // сам замер — когда VPN выключен (при открытии и после отключения), не чаще раза в час
    useEffect(() {
      if (vpnOff) Future.delayed(const Duration(seconds: 2), autoMeasure);
      return null;
    }, [vpnOff]);
    useOnAppLifecycleStateChange((_, s) {
      if (s == AppLifecycleState.resumed) {
        load();
        autoMeasure();
      }
    });

    final d = data.value ?? const <String, dynamic>{};
    final serverOk = d['available'] == true;

    final k = GorecTokens.of(context);
    final countries = serverOk
        ? ((d['countries'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    // какая страна выбрана сейчас — ищем её название в имени активного сервера
    final active = ref.watch(activeProxyNotifierProvider).valueOrNull;
    final activeName = '${active?.tagDisplay ?? ''} ${active?.groupSelectedTagDisplay ?? ''}'.toLowerCase();
    Map<String, dynamic>? current;
    for (final c in countries) {
      final name = (c['name'] as String? ?? '').replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '').trim().toLowerCase();
      if (name.isNotEmpty && activeName.contains(name)) {
        current = c;
        break;
      }
    }
    // если страна не определилась (например, автовыбор) — показываем самую быструю
    if (current == null && countries.isNotEmpty) {
      current = countries.reduce(
        (a, b) => ((a['vpn_mbps'] as num?) ?? 0) >= ((b['vpn_mbps'] as num?) ?? 0) ? a : b,
      );
    }
    final vpn = (current?['vpn_mbps'] as num?)?.toDouble();

    String mbps(double? v) => v == null ? '—' : '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} Мбит/с';

    String ago(DateTime? at) {
      if (at == null) return '';
      final m = DateTime.now().difference(at).inMinutes;
      if (m < 1) return 'только что';
      if (m < 60) return '$m мин назад';
      if (m < 60 * 24) return '${m ~/ 60} ч назад';
      return '${m ~/ (60 * 24)} дн назад';
    }

    String vpnNote() {
      if (!serverOk) return '';
      final samples = ((d['samples'] as num?) ?? 0).toInt();
      if (d['average'] == true && samples > 1) return 'с VPN — среднее за ${(d['period_days'] as num?)?.toInt() ?? 7} дн';
      final at = DateTime.tryParse((d['measured_at'] as String?) ?? '')?.toLocal();
      return at == null ? '' : 'с VPN — замер ${ago(at)}';
    }

    void onLocalTap() {
      if (measuring.value) return;
      if (!vpnOff) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Чтобы замерить скорость без VPN, сначала отключите VPN')),
        );
        return;
      }
      measure();
    }

    Widget cell(IconData icon, String label, Widget value) => Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: k.textDim),
              const Gap(4),
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: k.textDim, fontSize: 12.5)),
              ),
            ],
          ),
          const Gap(2),
          value,
        ],
      ),
    );

    Text valueText(String v, Color c) => Text(v, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 15));

    final Widget localValue;
    if (measuring.value) {
      localValue = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: k.accent)),
          const Gap(6),
          Text('замеряю…', style: TextStyle(color: k.textDim, fontSize: 13)),
        ],
      );
    } else if (local.value != null) {
      localValue = valueText(mbps(local.value), k.text);
    } else {
      localValue = Text(
        vpnOff ? 'Замерить' : '—',
        style: TextStyle(color: vpnOff ? k.accent : k.text, fontWeight: FontWeight.w700, fontSize: 15),
      );
    }

    final notes = [
      if (local.value != null && !measuring.value) 'без VPN — ваш замер ${ago(localAt.value)}',
      vpnNote(),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: 300,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(color: k.bgElev, borderRadius: BorderRadius.circular(GorecTokens.radiusSm)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Скорость', style: TextStyle(color: k.textDim, fontSize: 12, fontWeight: FontWeight.w600)),
            const Gap(6),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onLocalTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [cell(Icons.public_rounded, 'без VPN', localValue)]),
                    ),
                  ),
                ),
                Container(width: 1, height: 30, color: k.border),
                cell(
                  Icons.shield_rounded,
                  'с VPN${current?['name'] != null ? ' · ${current!['name']}' : ''}',
                  valueText(mbps(vpn), k.green),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const Gap(4),
              Text(notes, textAlign: TextAlign.center, style: TextStyle(color: k.textDim, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}
