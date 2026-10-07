import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/hamvpn/hamvpn_account.dart';
import 'package:hiddify/hamvpn/hamvpn_theme.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Маленькое окошко под кнопкой: скорость интернета без VPN и через выбранную страну.
/// Цифры — последние замеры бота мониторинга (он меряет из России), приходят с сайта.
class HamSpeedBox extends HookConsumerWidget {
  const HamSpeedBox({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = useState<Map<String, dynamic>?>(null);

    Future<void> load() async {
      try {
        data.value = await ref.read(hamApiProvider).speed();
      } catch (_) {}
    }

    useEffect(() {
      load();
      return null;
    }, const []);
    useOnAppLifecycleStateChange((_, s) {
      if (s == AppLifecycleState.resumed) load();
    });

    final d = data.value;
    if (d == null || d['available'] != true) return const SizedBox.shrink();

    final k = HamTokens.of(context);
    final direct = (d['direct_mbps'] as num?)?.toDouble();
    final countries = ((d['countries'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

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

    String ago() {
      final at = DateTime.tryParse((d['measured_at'] as String?) ?? '');
      if (at == null) return '';
      final m = DateTime.now().toUtc().difference(at).inMinutes;
      if (m < 60) return 'замер $m мин назад';
      if (m < 60 * 24) return 'замер ${m ~/ 60} ч назад';
      return 'замер ${m ~/ (60 * 24)} дн назад';
    }

    Widget cell(IconData icon, String label, String value, Color color) => Expanded(
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
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: 290,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(color: k.bgElev, borderRadius: BorderRadius.circular(HamTokens.radiusSm)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                cell(Icons.public_rounded, 'без VPN', mbps(direct), k.text),
                Container(width: 1, height: 30, color: k.border),
                cell(Icons.shield_rounded, 'с VPN${current?['name'] != null ? ' · ${current!['name']}' : ''}', mbps(vpn), k.green),
              ],
            ),
            const Gap(4),
            Text(ago(), style: TextStyle(color: k.textDim, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
