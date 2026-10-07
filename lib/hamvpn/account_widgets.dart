import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/hamvpn/hamvpn_account.dart';
import 'package:hiddify/hamvpn/hamvpn_api.dart';
import 'package:hiddify/hamvpn/hamvpn_theme.dart';
import 'package:hiddify/hamvpn/topup_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _open(String url) async {
  if (url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Обновляет данные аккаунта при показе и при каждом возврате в приложение.
void useHamAutoRefresh(WidgetRef ref) {
  useEffect(() {
    Future.microtask(() => ref.read(hamAccountProvider.notifier).refresh());
    return null;
  }, const []);
  useOnAppLifecycleStateChange((_, current) {
    if (current == AppLifecycleState.resumed) ref.read(hamAccountProvider.notifier).refresh();
  });
}

/// Компактная карточка на главном экране: статус, сколько дней осталось, баланс, «Пополнить».
class HamAccountCard extends HookConsumerWidget {
  const HamAccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = HamTokens.of(context);
    final account = ref.watch(hamAccountProvider);
    useHamAutoRefresh(ref);

    final hasData = account.me != null;
    final active = account.hasActiveConfig;
    final days = account.daysLeft;
    final low = active && !account.trialActive && days <= 3;

    final (String status, Color color, Color soft) = !hasData
        ? (account.error != null ? 'Нет связи с сервером' : 'Загрузка…', k.textDim, k.bgSunken)
        : !active
        ? ('Приостановлен — пополните баланс', k.red, k.redSoft)
        : account.trialActive
        ? ('Пробный период', k.green, k.greenSoft)
        : low
        ? ('Скоро закончится', k.amber, k.amberSoft)
        : ('Активен', k.green, k.greenSoft);

    return HamCard(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      borderColor: !hasData ? null : (!active ? k.red : (low ? k.amber : null)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HamStatusDot(color: color, soft: soft),
              const Gap(10),
              Expanded(
                child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ),
              if (account.loading)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: k.textDim)),
            ],
          ),
          const Gap(10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasData ? (active ? 'Осталось ${hamDays(days)}' : 'VPN на паузе') : '—',
                      style: TextStyle(color: k.text, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                    ),
                    const Gap(2),
                    Text(
                      hasData ? 'Баланс ${hamRub(account.balanceRub)} · ${account.login}' : ' ',
                      style: TextStyle(color: k.textDim),
                    ),
                  ],
                ),
              ),
              const Gap(10),
              FilledButton(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
                onPressed: hasData ? () => HamTopupPage.open(context) : null,
                child: const Text('Пополнить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Вкладка «Аккаунт» (нижнее меню) — повторяет личный кабинет сайта.
class HamAccountPage extends HookConsumerWidget {
  const HamAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = HamTokens.of(context);
    final account = ref.watch(hamAccountProvider);
    useHamAutoRefresh(ref);

    void snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

    Future<void> promo() async {
      final controller = TextEditingController();
      final code = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Промокод'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Введите промокод'),
          ),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Применить')),
          ],
        ),
      );
      if (code == null || code.isEmpty) return;
      try {
        snack(await ref.read(hamAccountProvider.notifier).redeemPromo(code));
      } on HamApiException catch (e) {
        snack(e.message);
      }
    }

    Future<void> invite() async {
      final link = account.link('referral');
      if (link.isEmpty) return;
      await Share.share('Подключайся к Хам VPN — первые дни бесплатно, а по моей ссылке ещё и бонус: $link');
    }

    Future<void> logout() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Выйти из аккаунта?'),
          content: const Text('VPN на этом устройстве отключится. Войти снова можно тем же логином и паролем.'),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: k.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Выйти'),
            ),
          ],
        ),
      );
      if (ok == true) await ref.read(hamAccountProvider.notifier).logout();
    }

    Widget row(IconData icon, String title, VoidCallback onTap, {String? subtitle}) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: k.accent, size: 22),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: k.text, fontSize: 16, fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const Gap(2),
                    Text(subtitle, style: TextStyle(color: k.textDim, fontSize: 13.5)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: k.textDim),
          ],
        ),
      ),
    );

    Widget sep() => Divider(color: k.border, height: 1);

    final hasData = account.me != null;
    final active = account.hasActiveConfig;

    return Scaffold(
      appBar: AppBar(title: const Text('Личный кабинет')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(hamAccountProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
          children: [
            if (account.trialActive)
              HamCard(
                borderColor: k.green,
                padding: const EdgeInsets.all(16),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(color: k.text, fontSize: 15),
                    children: [
                      const TextSpan(text: 'Пробный период активен', style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: ' — осталось ${hamDays(((account.trial['days_left'] as num?) ?? 0).toInt())}. Пользуйтесь бесплатно!'),
                    ],
                  ),
                ),
              ),
            if (account.error != null && !hasData)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: HamFlash(text: account.error!, color: k.red, soft: k.redSoft),
              ),
            HamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Логин: ', style: TextStyle(color: k.text, fontSize: 15)),
                      Text(account.login, style: TextStyle(color: k.text, fontSize: 15, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (account.login.isNotEmpty)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            textStyle: const TextStyle(fontSize: 13.5),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: account.login));
                            snack('Логин скопирован');
                          },
                          child: const Text('Скопировать'),
                        ),
                    ],
                  ),
                  const Gap(4),
                  Text(
                    'Telegram: ${account.user['telegram_linked'] == true ? 'привязан ✅' : 'не привязан'}',
                    style: TextStyle(color: k.text, fontSize: 15),
                  ),
                  const Gap(12),
                  Text(
                    hasData ? hamRub(account.balanceRub) : '—',
                    style: TextStyle(color: k.text, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  ),
                  Row(
                    children: [
                      HamStatusDot(
                        color: active ? k.green : k.red,
                        soft: active ? k.greenSoft : k.redSoft,
                      ),
                      const Gap(8),
                      Text(
                        !hasData
                            ? ''
                            : active
                            ? 'VPN работает · хватит примерно на ${hamDays(account.daysLeft)}'
                            : 'VPN приостановлен — пополните баланс',
                        style: TextStyle(color: k.textDim),
                      ),
                    ],
                  ),
                  const Gap(4),
                  Text(
                    'Тариф — ${account.pricePerMonth} ₽ в месяц за одно устройство, списывается посуточно.',
                    style: TextStyle(color: k.textDim, fontSize: 13.5),
                  ),
                  const Gap(14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: hasData ? () => HamTopupPage.open(context) : null,
                      child: const Text('Пополнить баланс'),
                    ),
                  ),
                ],
              ),
            ),
            HamCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Column(
                children: [
                  row(Icons.card_giftcard_rounded, 'Ввести промокод', promo),
                  sep(),
                  row(
                    Icons.payments_rounded,
                    'Заработать с нами',
                    invite,
                    subtitle: 'Другу — бонусные дни, вам — процент с каждой его оплаты',
                  ),
                ],
              ),
            ),
            HamCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Column(
                children: [
                  row(Icons.menu_book_rounded, 'Инструкции', () => _open(account.link('instructions'))),
                  sep(),
                  row(
                    Icons.support_agent_rounded,
                    'Поддержка',
                    () => _open(account.link('support_bot')),
                    subtitle: 'Напишите нам в Telegram-бота',
                  ),
                  sep(),
                  row(Icons.language_rounded, 'Кабинет на сайте', () => _open(account.link('site'))),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: k.red,
                  backgroundColor: k.redSoft,
                  side: BorderSide(color: k.red),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: logout,
                child: const Text('Выйти из аккаунта'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
