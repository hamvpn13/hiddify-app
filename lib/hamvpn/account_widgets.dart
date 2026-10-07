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

/// Карточка аккаунта на главном экране: сколько дней осталось, баланс, «Пополнить».
/// Обновляется при открытии и каждый раз, когда приложение возвращается на экран.
class HamAccountCard extends HookConsumerWidget {
  const HamAccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(hamAccountProvider);

    useEffect(() {
      Future.microtask(() => ref.read(hamAccountProvider.notifier).refresh());
      return null;
    }, const []);
    useOnAppLifecycleStateChange((_, current) {
      if (current == AppLifecycleState.resumed) ref.read(hamAccountProvider.notifier).refresh();
    });

    final hasData = account.me != null;
    final active = account.hasActiveConfig;
    final days = account.daysLeft;
    final low = active && days <= 3;

    final String status;
    final Color statusColor;
    if (!hasData) {
      status = account.error != null ? 'Нет связи с сервером' : 'Загрузка…';
      statusColor = Colors.white70;
    } else if (!active) {
      status = 'Приостановлен — пополните баланс';
      statusColor = HamColors.bad;
    } else if (account.trialActive) {
      status = 'Пробный период';
      statusColor = HamColors.gold;
    } else {
      status = low ? 'Скоро закончится' : 'Активен';
      statusColor = low ? HamColors.warn : HamColors.ok;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: HamColors.cardGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const Gap(8),
                Expanded(
                  child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                ),
                if (account.loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  ),
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
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const Gap(2),
                      Text(
                        hasData ? 'Баланс ${hamRub(account.balanceRub)} · ${account.login}' : ' ',
                        style: TextStyle(color: Colors.white.withValues(alpha: .75)),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: HamColors.gold,
                    foregroundColor: HamColors.night,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: hasData ? () => HamTopupPage.open(context) : null,
                  child: const Text('Пополнить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Экран «Аккаунт»: пополнение, промокод, приглашение друга, инструкции, поддержка, выход.
class HamAccountPage extends HookConsumerWidget {
  const HamAccountPage({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HamAccountPage()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(hamAccountProvider);
    final theme = Theme.of(context);

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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Применить')),
          ],
        ),
      );
      if (code == null || code.isEmpty) return;
      try {
        final msg = await ref.read(hamAccountProvider.notifier).redeemPromo(code);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      } on HamApiException catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    Future<void> invite() async {
      final link = account.link('referral');
      if (link.isEmpty) return;
      await Share.share(
        'Подключайся к ХамВПН — быстрый VPN, первые дни бесплатно (по моей ссылке ещё и бонус): $link',
      );
    }

    Future<void> logout() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Выйти из аккаунта?'),
          content: const Text('VPN на этом устройстве отключится. Войти снова можно тем же логином и паролем.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Выйти')),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(hamAccountProvider.notifier).logout();
        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
    }

    Widget tile(IconData icon, String title, VoidCallback onTap, {String? subtitle, Color? color}) => ListTile(
      leading: Icon(icon, color: color ?? HamColors.rose),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Аккаунт')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(hamAccountProvider.notifier).refresh(),
        child: ListView(
          children: [
            const HamAccountCard(),
            if (account.login.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text(account.login),
                subtitle: const Text('Ваш логин — им же входите на сайт и в бота'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: account.login));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Логин скопирован')));
                  },
                ),
              ),
            const Divider(),
            tile(Icons.account_balance_wallet_rounded, 'Пополнить баланс', () => HamTopupPage.open(context)),
            tile(Icons.card_giftcard_rounded, 'Ввести промокод', promo),
            tile(
              Icons.payments_rounded,
              'Заработать с нами',
              invite,
              subtitle: 'Поделитесь ссылкой: другу — бонусные дни, вам — процент с его оплат',
            ),
            const Divider(),
            tile(Icons.menu_book_rounded, 'Инструкции', () => _open(account.link('instructions'))),
            tile(Icons.support_agent_rounded, 'Поддержка', () => _open(account.link('support_bot')),
                subtitle: 'Напишите нам в Telegram-бота'),
            tile(Icons.language_rounded, 'Личный кабинет на сайте', () => _open(account.link('site'))),
            tile(Icons.policy_rounded, 'Политика и условия', () => _open(account.link('policy'))),
            const Divider(),
            tile(Icons.logout_rounded, 'Выйти из аккаунта', logout, color: theme.colorScheme.error),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}
