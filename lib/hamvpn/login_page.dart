import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/hamvpn/hamvpn_account.dart';
import 'package:hiddify/hamvpn/hamvpn_api.dart';
import 'package:hiddify/hamvpn/hamvpn_theme.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Первый экран: вход или регистрация в аккаунте ХамВПН
/// (тот же логин и пароль, что на сайте и в боте).
class HamLoginPage extends HookConsumerWidget {
  const HamLoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRegister = useState(false);
    final login = useTextEditingController();
    final password = useTextEditingController();
    final password2 = useTextEditingController();
    final refCode = useTextEditingController();
    final showRef = useState(false);
    final hidePassword = useState(true);
    final error = useState<String?>(null);
    final busy = ref.watch(hamAccountProvider).loading;

    Future<void> submit() async {
      FocusScope.of(context).unfocus();
      error.value = null;
      final l = login.text.trim();
      final p = password.text;
      if (l.isEmpty || p.isEmpty) {
        error.value = 'Введите логин и пароль.';
        return;
      }
      final notifier = ref.read(hamAccountProvider.notifier);
      if (isRegister.value) {
        if (p != password2.text) {
          error.value = 'Пароли не совпадают.';
          return;
        }
        error.value = await notifier.register(l, p, ref: refCode.text.trim());
      } else {
        error.value = await notifier.login(l, p);
      }
    }

    InputDecoration field(String label, {Widget? suffix, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: .08),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: .75)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: .4)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: .15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HamColors.gold, width: 1.5),
      ),
    );

    final eye = IconButton(
      icon: Icon(hidePassword.value ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.white70),
      onPressed: () => hidePassword.value = !hidePassword.value,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: HamColors.skyGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    textSelectionTheme: const TextSelectionThemeData(cursorColor: HamColors.gold),
                  ),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Colors.white),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: Image.asset('assets/images/hamvpn_logo.png', width: 112, height: 112)),
                        const Gap(16),
                        const Text(
                          'ХамВПН',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const Gap(6),
                        Text(
                          isRegister.value
                              ? 'Создайте аккаунт — пробный период включится сразу'
                              : 'Войдите тем же логином, что на сайте и в боте',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: .75)),
                        ),
                        const Gap(24),
                        _Segment(
                          isRegister: isRegister.value,
                          onChanged: (v) {
                            isRegister.value = v;
                            error.value = null;
                          },
                        ),
                        const Gap(18),
                        TextField(
                          controller: login,
                          style: const TextStyle(color: Colors.white),
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          decoration: field(
                            'Логин',
                            hint: isRegister.value ? 'латинские буквы и цифры' : null,
                          ),
                        ),
                        const Gap(12),
                        TextField(
                          controller: password,
                          obscureText: hidePassword.value,
                          style: const TextStyle(color: Colors.white),
                          textInputAction: isRegister.value ? TextInputAction.next : TextInputAction.done,
                          onSubmitted: (_) => isRegister.value ? null : submit(),
                          decoration: field('Пароль', suffix: eye),
                        ),
                        if (isRegister.value) ...[
                          const Gap(12),
                          TextField(
                            controller: password2,
                            obscureText: hidePassword.value,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => submit(),
                            decoration: field('Повторите пароль'),
                          ),
                          const Gap(8),
                          if (!showRef.value)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => showRef.value = true,
                                child: const Text('У меня есть код приглашения', style: TextStyle(color: HamColors.gold)),
                              ),
                            )
                          else ...[
                            const Gap(4),
                            TextField(
                              controller: refCode,
                              style: const TextStyle(color: Colors.white),
                              textCapitalization: TextCapitalization.characters,
                              decoration: field('Код приглашения (необязательно)'),
                            ),
                          ],
                        ],
                        if (error.value != null) ...[
                          const Gap(14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: HamColors.bad.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: HamColors.bad.withValues(alpha: .5)),
                            ),
                            child: Text(error.value!, style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                        const Gap(20),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: HamColors.gold,
                              foregroundColor: HamColors.night,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            onPressed: busy ? null : submit,
                            child: busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: HamColors.night),
                                  )
                                : Text(isRegister.value ? 'Зарегистрироваться' : 'Войти'),
                          ),
                        ),
                        const Gap(12),
                        if (!isRegister.value)
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse('$kHamSiteUrl/forgot'),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: Text('Забыли пароль?', style: TextStyle(color: Colors.white.withValues(alpha: .8))),
                          ),
                        const Gap(8),
                        Text(
                          'Регистрируясь, вы принимаете условия использования.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .5)),
                        ),
                        TextButton(
                          onPressed: () => launchUrl(Uri.parse('$kHamSiteUrl/policy'), mode: LaunchMode.externalApplication),
                          child: Text(
                            'Политика и условия',
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.isRegister, required this.onChanged});

  final bool isRegister;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(String text, bool value) {
      final selected = isRegister == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withValues(alpha: .16) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withValues(alpha: .6),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .18), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [item('Вход', false), item('Регистрация', true)]),
    );
  }
}
