import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/hamvpn/hamvpn_account.dart';
import 'package:hiddify/hamvpn/hamvpn_api.dart';
import 'package:hiddify/hamvpn/hamvpn_theme.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Загрузка данных с сайта с состояниями «грузится / ошибка / готово».
class _Loader extends StatelessWidget {
  const _Loader({required this.error, required this.loading, required this.onRetry, required this.child});

  final String? error;
  final bool loading;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const Gap(12),
              FilledButton.tonal(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    if (loading) return const Center(child: CircularProgressIndicator());
    return child;
  }
}

/// Инструкции — текст берётся с сайта (/api/app/v1/instructions), его можно менять без обновления приложения.
class HamInstructionsPage extends HookConsumerWidget {
  const HamInstructionsPage({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HamInstructionsPage()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = useState<String?>(null);
    final error = useState<String?>(null);

    Future<void> load() async {
      error.value = null;
      try {
        final data = await ref.read(hamApiProvider).instructions();
        text.value = (data['markdown'] as String?) ?? '';
      } on HamApiException catch (e) {
        error.value = e.message;
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Инструкции')),
      body: _Loader(
        error: error.value,
        loading: text.value == null,
        onRetry: load,
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              MarkdownBody(
                data: text.value ?? '',
                onTapLink: (_, href, __) {
                  if (href != null) launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                },
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  h2Padding: const EdgeInsets.only(top: 18, bottom: 4),
                  p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  listBullet: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Заработать с нами» — как раздел на сайте, все цифры и условия приходят с сервера.
class HamReferralPage extends HookConsumerWidget {
  const HamReferralPage({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HamReferralPage()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = useState<Map<String, dynamic>?>(null);
    final error = useState<String?>(null);
    final busy = useState(false);
    final k = HamTokens.of(context);
    final theme = Theme.of(context);

    Future<void> load() async {
      error.value = null;
      try {
        data.value = await ref.read(hamAccountProvider.notifier).referral();
      } on HamApiException catch (e) {
        error.value = e.message;
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    void snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

    final d = data.value ?? const <String, dynamic>{};
    final stats = Map<String, dynamic>.from((d['stats'] as Map?) ?? const {});
    double num0(Object? v) => ((v as num?) ?? 0).toDouble();
    final balance = num0(stats['balance_rub']);
    final minPayout = num0(d['min_payout_rub']);
    final link = (d['link'] as String?) ?? '';
    final botLink = (d['bot_link'] as String?) ?? '';

    Future<void> transfer() async {
      busy.value = true;
      try {
        snack(await ref.read(hamAccountProvider.notifier).referralTransfer());
        await load();
      } on HamApiException catch (e) {
        snack(e.message);
      } finally {
        busy.value = false;
      }
    }

    Future<void> payout() async {
      final amount = TextEditingController(text: balance > 0 ? balance.toStringAsFixed(0) : '');
      final details = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Вывести на карту'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Сумма, ₽ (от ${minPayout.toStringAsFixed(0)})'),
              ),
              const Gap(12),
              TextField(
                controller: details,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Куда перевести', hintText: 'Номер карты или телефон для СБП и банк'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отправить заявку')),
          ],
        ),
      );
      if (ok != true) return;
      busy.value = true;
      try {
        snack(await ref.read(hamAccountProvider.notifier).referralPayout(amount.text, details.text));
        await load();
      } on HamApiException catch (e) {
        snack(e.message);
      } finally {
        busy.value = false;
      }
    }

    Widget stat(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: k.bgElev, borderRadius: BorderRadius.circular(HamTokens.radiusSm)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(color: k.textDim, fontSize: 13)),
          ],
        ),
      ),
    );

    final ledger = ((d['ledger'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Заработать с нами')),
      body: _Loader(
        error: error.value,
        loading: data.value == null,
        onRetry: load,
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              HamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Приглашайте друзей', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Gap(8),
                    Text(
                      'Друг получит ${d['bonus_days'] ?? 0} бонусных дней к пробному периоду, а вы — '
                      '${d['percent'] ?? 0}% с каждой его оплаты в течение ${d['period_months'] ?? 12} месяцев. '
                      'Эти деньги можно перевести на свой баланс VPN или вывести на карту от ${minPayout.toStringAsFixed(0)} ₽.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                    const Gap(14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: k.bgSunken, borderRadius: BorderRadius.circular(HamTokens.radiusSm)),
                      child: SelectableText(link, style: const TextStyle(fontSize: 13.5)),
                    ),
                    const Gap(10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.share_rounded),
                            onPressed: link.isEmpty
                                ? null
                                : () => Share.share('Подключайся к Хам VPN — первые дни бесплатно, по моей ссылке ещё и бонус: $link'),
                            label: const Text('Поделиться'),
                          ),
                        ),
                        const Gap(8),
                        IconButton.filledTonal(
                          tooltip: 'Скопировать ссылку',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: link));
                            snack('Ссылка скопирована');
                          },
                        ),
                      ],
                    ),
                    if (botLink.isNotEmpty) ...[
                      const Gap(6),
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: botLink));
                          snack('Ссылка на бота скопирована');
                        },
                        child: const Text('Скопировать ссылку для Telegram-бота'),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  stat('приглашено', '${stats['invited'] ?? 0}'),
                  const Gap(8),
                  stat('оплачивали', '${stats['paying'] ?? 0}'),
                  const Gap(8),
                  stat('заработано', hamRub(num0(stats['earned_rub']))),
                ],
              ),
              const Gap(12),
              HamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ваши реферальные деньги', style: TextStyle(color: k.textDim)),
                    Text(hamRub(balance), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (num0(stats['pending_payout_rub']) > 0)
                      Text('Ждёт вывода: ${hamRub(num0(stats['pending_payout_rub']))}', style: TextStyle(color: k.amber)),
                    const Gap(12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: busy.value || balance <= 0 ? null : transfer,
                            child: const Text('На баланс VPN'),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy.value || balance < minPayout ? null : payout,
                            child: const Text('На карту'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (ledger.isNotEmpty) ...[
                const Gap(8),
                Text('История', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Gap(6),
                for (final r in ledger)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r['title'] as String? ?? ''),
                    subtitle: Text([
                      if (r['from'] != null) 'от ${r['from']}',
                      ((r['at'] as String?) ?? '').split(' ').first,
                    ].join(' · ')),
                    trailing: Text(
                      '${num0(r['amount_rub']) >= 0 ? '+' : ''}${hamRub(num0(r['amount_rub']))}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: num0(r['amount_rub']) >= 0 ? k.green : k.red,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
