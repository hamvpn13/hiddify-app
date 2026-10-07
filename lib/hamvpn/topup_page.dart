import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/hamvpn/hamvpn_account.dart';
import 'package:hiddify/hamvpn/hamvpn_api.dart';
import 'package:hiddify/hamvpn/hamvpn_theme.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Пополнение баланса: срок (1/3/6 мес. со скидками) → карта или СБП → страница Lava.
/// Деньги зачисляет сервер по уведомлению Lava; приложение просто ждёт и обновляет баланс.
class HamTopupPage extends HookConsumerWidget {
  const HamTopupPage({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HamTopupPage()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = useState<List<Map<String, dynamic>>?>(null);
    final methods = useState<List<Map<String, dynamic>>>(const []);
    final loadError = useState<String?>(null);
    final months = useState(1);
    final method = useState('card');
    final paying = useState(false);
    final waitingId = useState<int?>(null);
    final paid = useState(false);
    final account = ref.watch(hamAccountProvider);

    Future<void> load() async {
      loadError.value = null;
      try {
        final notifier = ref.read(hamAccountProvider.notifier);
        plans.value = await notifier.plans();
        methods.value = await notifier.payMethods();
      } on HamApiException catch (e) {
        loadError.value = e.message;
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    Future<void> checkPaid() async {
      final id = waitingId.value;
      if (id == null || paid.value) return;
      try {
        final status = await ref.read(hamAccountProvider.notifier).topupStatus(id);
        if (status == 'approved') {
          paid.value = true;
          await ref.read(hamAccountProvider.notifier).refresh();
        }
      } catch (_) {}
    }

    // Пока ждём оплату — опрашиваем сервер каждые 4 секунды (не дольше 10 минут)
    useEffect(() {
      if (waitingId.value == null || paid.value) return null;
      var ticks = 0;
      final timer = Timer.periodic(const Duration(seconds: 4), (t) {
        ticks++;
        if (ticks > 150) t.cancel();
        checkPaid();
      });
      return timer.cancel;
    }, [waitingId.value, paid.value]);

    useOnAppLifecycleStateChange((_, current) {
      if (current == AppLifecycleState.resumed) checkPaid();
    });

    Future<void> pay() async {
      paying.value = true;
      try {
        final (url, id) = await ref.read(hamAccountProvider.notifier).createTopup(months.value, method.value);
        waitingId.value = id;
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } on HamApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      } finally {
        paying.value = false;
      }
    }

    final theme = Theme.of(context);

    Widget body;
    if (paid.value) {
      body = _Done(daysLeft: account.daysLeft, balance: account.balanceRub);
    } else if (loadError.value != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loadError.value!, textAlign: TextAlign.center),
              const Gap(12),
              FilledButton(onPressed: load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    } else if (plans.value == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Баланс: ${hamRub(account.balanceRub)}',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap(4),
          Text(
            'Тариф — ${account.pricePerMonth} ₽ в месяц за одно устройство, списывается по дням.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Gap(20),
          Text('На какой срок', style: theme.textTheme.titleSmall),
          const Gap(10),
          for (final p in plans.value!)
            _PlanTile(
              months: (p['months'] as num).toInt(),
              amount: (p['amount_rub'] as num).toDouble(),
              discount: (p['discount_pct'] as num).toInt(),
              selected: months.value == (p['months'] as num).toInt(),
              onTap: () => months.value = (p['months'] as num).toInt(),
            ),
          const Gap(16),
          Text('Как оплатить', style: theme.textTheme.titleSmall),
          const Gap(10),
          if (methods.value.isEmpty)
            const Text('Онлайн-оплата сейчас недоступна. Напишите в поддержку через бота.')
          else
            Row(
              children: [
                for (final m in methods.value) ...[
                  Expanded(
                    child: _MethodChip(
                      title: m['title'] as String,
                      icon: m['id'] == 'sbp' ? Icons.bolt_rounded : Icons.credit_card_rounded,
                      selected: method.value == m['id'],
                      onTap: () => method.value = m['id'] as String,
                    ),
                  ),
                  if (m != methods.value.last) const Gap(10),
                ],
              ],
            ),
          const Gap(24),
          if (waitingId.value != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  Gap(12),
                  Expanded(
                    child: Text('Ждём подтверждение оплаты. Если уже оплатили — баланс обновится сам за минуту.'),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: HamColors.gold,
                foregroundColor: HamColors.night,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              onPressed: paying.value || methods.value.isEmpty ? null : pay,
              child: paying.value
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(waitingId.value == null ? 'Оплатить' : 'Открыть оплату ещё раз'),
            ),
          ),
          const Gap(12),
          Text(
            'Оплата проходит на защищённой странице платёжного сервиса Lava. '
            'После оплаты вернитесь в приложение — баланс пополнится автоматически.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return Scaffold(appBar: AppBar(title: const Text('Пополнить баланс')), body: body);
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.months,
    required this.amount,
    required this.discount,
    required this.selected,
    required this.onTap,
  });

  final int months;
  final double amount;
  final int discount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (months) {
      1 => '1 месяц',
      3 => '3 месяца',
      6 => '6 месяцев',
      _ => '$months мес.',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? HamColors.rose.withValues(alpha: .14) : theme.colorScheme.surfaceContainer,
            border: Border.all(color: selected ? HamColors.rose : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? HamColors.rose : theme.colorScheme.outline,
              ),
              const Gap(12),
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (discount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: HamColors.ok, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '−$discount%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              Text(hamRub(amount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({required this.title, required this.icon, required this.selected, required this.onTap});

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? HamColors.rose.withValues(alpha: .14) : theme.colorScheme.surfaceContainer,
          border: Border.all(color: selected ? HamColors.rose : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? HamColors.rose : theme.colorScheme.onSurfaceVariant),
            const Gap(6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.daysLeft, required this.balance});

  final int daysLeft;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: HamColors.ok, size: 72),
            const Gap(16),
            Text('Оплата получена!', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const Gap(8),
            Text(
              'Баланс: ${hamRub(balance)}. Хватит примерно на ${hamDays(daysLeft)}.',
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Готово')),
          ],
        ),
      ),
    );
  }
}
