import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/hamvpn/hamvpn_theme.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

/// ХамВПН: короткие и понятные настройки для обычного человека.
/// Технические разделы Hiddify (DNS, входящие порты, TLS-трюки, WARP, ядро и т.п.)
/// убраны из интерфейса — их значения по умолчанию подходят всем.
class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = HamTokens.of(context);
    final ruDirect = ref.watch(ConfigOptions.region) == Region.ru;
    final perApp = ref.watch(Preferences.perAppProxyMode);

    Widget group(String title, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(title, style: TextStyle(color: k.textDim, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: k.bgElev,
            borderRadius: BorderRadius.circular(HamTokens.radius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) Divider(color: k.border.withValues(alpha: .5), height: 1, indent: 56, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );

    Widget toggle({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) => SwitchListTile(
      secondary: Icon(icon, color: k.accent),
      title: Text(title, style: TextStyle(color: k.text, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: k.textDim, fontSize: 13.5)),
      value: value,
      onChanged: onChanged,
    );

    Widget link({required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) =>
        ListTile(
          leading: Icon(icon, color: k.accent),
          title: Text(title, style: TextStyle(color: k.text, fontWeight: FontWeight.w500)),
          subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: k.textDim, fontSize: 13.5)),
          trailing: Icon(Icons.chevron_right_rounded, color: k.textDim),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 40),
        children: [
          group('Основное', [
            const LocalePrefTile(),
            const ThemeModePrefTile(),
            toggle(
              icon: Icons.vibration_rounded,
              title: 'Вибрация при нажатии',
              subtitle: 'Лёгкий отклик, когда включаете и выключаете VPN',
              value: ref.watch(hapticServiceProvider),
              onChanged: ref.read(hapticServiceProvider.notifier).updatePreference,
            ),
          ]),
          group('Работа VPN', [
            toggle(
              icon: Icons.flag_rounded,
              title: 'Российские сайты — без VPN',
              subtitle: 'Банки, Госуслуги, маркетплейсы открываются напрямую и быстрее',
              value: ruDirect,
              onChanged: (v) async {
                await ref.read(ConfigOptions.directDnsAddress.notifier).reset();
                await ref.read(ConfigOptions.region.notifier).update(v ? Region.ru : Region.other);
              },
            ),
            toggle(
              icon: Icons.block_rounded,
              title: 'Блокировать рекламу',
              subtitle: 'Отсекает известные рекламные адреса',
              value: ref.watch(ConfigOptions.blockAds),
              onChanged: ref.read(ConfigOptions.blockAds.notifier).update,
            ),
            if (PlatformUtils.isAndroid)
              link(
                icon: Icons.apps_rounded,
                title: 'Приложения без VPN',
                subtitle: perApp == PerAppProxyMode.off
                    ? 'Сейчас через VPN работают все приложения'
                    : 'Выбраны приложения, которые работают мимо VPN',
                onTap: () async {
                  if (perApp == PerAppProxyMode.off) {
                    await ref.read(Preferences.perAppProxyMode.notifier).update(PerAppProxyMode.exclude);
                  }
                  if (context.mounted) context.goNamed('perAppProxy');
                },
              ),
            if (PlatformUtils.isAndroid && perApp != PerAppProxyMode.off)
              link(
                icon: Icons.restart_alt_rounded,
                title: 'Снова пустить всё через VPN',
                onTap: () => ref.read(Preferences.perAppProxyMode.notifier).update(PerAppProxyMode.off),
              ),
            toggle(
              icon: Icons.speed_rounded,
              title: 'Скорость в уведомлении',
              subtitle: 'Показывать скорость загрузки в шторке, пока VPN включён',
              value: ref.watch(Preferences.dynamicNotification),
              onChanged: ref.read(Preferences.dynamicNotification.notifier).update,
            ),
          ]),
          group('Помощь', [
            link(
              icon: Icons.description_rounded,
              title: 'Журнал работы',
              subtitle: 'Пригодится поддержке, если что-то не подключается',
              onTap: () => context.goNamed('logs'),
            ),
            link(icon: Icons.info_rounded, title: 'О программе', onTap: () => context.goNamed('about')),
            link(
              icon: Icons.settings_backup_restore_rounded,
              title: 'Сбросить настройки',
              subtitle: 'Вернуть всё как было после установки',
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Сбросить настройки?'),
                    content: const Text('Аккаунт и подписка останутся, вернутся только настройки приложения.'),
                    actions: [
                      OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сбросить')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(configOptionNotifierProvider.notifier).resetOption();
                  // для России российские сайты по-прежнему напрямую
                  await ref.read(ConfigOptions.region.notifier).update(Region.ru);
                }
              },
            ),
          ]),
          const Gap(8),
        ],
      ),
    );
  }
}

/// Оставлено для совместимости с другими экранами Hiddify.
class SettingsSection extends HookConsumerWidget {
  const SettingsSection({super.key, required this.title, required this.icon, required this.namedLocation});

  final String title;
  final IconData icon;
  final String namedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(namedLocation),
    );
  }
}
