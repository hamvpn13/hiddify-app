import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/hamvpn/hamvpn_account.dart';
import 'package:hiddify/hamvpn/hamvpn_api.dart';
import 'package:hiddify/hamvpn/hamvpn_theme.dart';
import 'package:hiddify/hamvpn/info_pages.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Первый экран: вход или регистрация (тот же логин и пароль, что на сайте и в боте).
/// Оформлен как страницы /login и /register на сайте.
class HamLoginPage extends HookConsumerWidget {
  const HamLoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = HamTokens.of(context);
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

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(color: k.textDim, fontSize: 14)),
    );

    final eye = IconButton(
      icon: Icon(hidePassword.value ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: k.textDim),
      onPressed: () => hidePassword.value = !hidePassword.value,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/hamvpn_logo.png', width: 44, height: 44),
                      const Gap(10),
                      Text('Хам VPN', style: TextStyle(color: k.text, fontSize: 22, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const Gap(24),
                  Text(
                    isRegister.value ? 'Регистрация' : 'Вход',
                    style: TextStyle(color: k.text, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  ),
                  const Gap(6),
                  Text(
                    isRegister.value
                        ? 'Пробный период включится сразу после регистрации.'
                        : 'Тот же логин и пароль, что на сайте и в боте.',
                    style: TextStyle(color: k.textDim, fontSize: 16),
                  ),
                  const Gap(20),
                  if (error.value != null) ...[
                    HamFlash(text: error.value!, color: k.red, soft: k.redSoft),
                    const Gap(12),
                  ],
                  HamCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        label('Логин'),
                        TextField(
                          controller: login,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: isRegister.value ? 'латинские буквы, цифры, точка' : null,
                          ),
                        ),
                        const Gap(16),
                        label('Пароль'),
                        TextField(
                          controller: password,
                          obscureText: hidePassword.value,
                          textInputAction: isRegister.value ? TextInputAction.next : TextInputAction.done,
                          onSubmitted: (_) => isRegister.value ? null : submit(),
                          decoration: InputDecoration(
                            suffixIcon: eye,
                            hintText: isRegister.value ? 'не короче 6 символов' : null,
                          ),
                        ),
                        if (isRegister.value) ...[
                          const Gap(16),
                          label('Пароль ещё раз'),
                          TextField(
                            controller: password2,
                            obscureText: hidePassword.value,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => submit(),
                          ),
                          const Gap(8),
                          if (!showRef.value)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                onPressed: () => showRef.value = true,
                                child: const Text('У меня есть код приглашения'),
                              ),
                            )
                          else ...[
                            const Gap(8),
                            label('Код приглашения (необязательно)'),
                            TextField(controller: refCode, textCapitalization: TextCapitalization.characters),
                          ],
                        ],
                        const Gap(20),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          child: busy
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: k.accentInk),
                                )
                              : Text(isRegister.value ? 'Зарегистрироваться' : 'Войти'),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isRegister.value ? 'Уже есть аккаунт?' : 'Нет аккаунта?', style: TextStyle(color: k.textDim)),
                      TextButton(
                        onPressed: () {
                          isRegister.value = !isRegister.value;
                          error.value = null;
                        },
                        child: Text(isRegister.value ? 'Войти' : 'Зарегистрироваться'),
                      ),
                    ],
                  ),
                  if (!isRegister.value)
                    TextButton(
                      onPressed: () =>
                          launchUrl(Uri.parse('$kHamSiteUrl/forgot'), mode: LaunchMode.externalApplication),
                      child: Text('Забыли пароль?', style: TextStyle(color: k.textDim)),
                    ),
                  const Gap(16),
                  Divider(color: k.border),
                  const Gap(8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => HamInfoPage.open(context, HamInfo.terms),
                        child: Text('Условия использования', style: TextStyle(color: k.textDim, fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () => HamInfoPage.open(context, HamInfo.privacy),
                        child: Text('Конфиденциальность', style: TextStyle(color: k.textDim, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
