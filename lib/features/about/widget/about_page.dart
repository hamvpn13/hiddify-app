import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/widget/adaptive_icon.dart';
import 'package:hiddify/hamvpn/updater.dart';
import 'package:hiddify/hamvpn/hamvpn_api.dart';
import 'package:hiddify/hamvpn/info_pages.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AboutPage extends HookConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final appInfo = ref.watch(appInfoProvider).requireValue;
    final conditionalTiles = [
      if (PlatformUtils.isAndroid)
        ListTile(
          title: const Text('Проверить обновления'),
          subtitle: Text('Установлена версия ${appInfo.version}'),
          trailing: const Icon(FluentIcons.arrow_sync_24_regular),
          onTap: () => HamUpdater.manualCheck(context, ref),
        ),
      if (PlatformUtils.isDesktop)
        ListTile(
          title: Text(t.pages.about.openWorkingDir),
          trailing: const Icon(FluentIcons.open_folder_24_regular),
          onTap: () async {
            final path = ref.watch(appDirectoriesProvider).requireValue.workingDir.uri;
            await UriUtils.tryLaunch(path);
          },
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.about.title),
        actions: [
          PopupMenuButton(
            icon: Icon(AdaptiveIcon(context).more),
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  child: Text(t.common.addToClipboard),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: appInfo.format()));
                  },
                ),
              ];
            },
          ),
          const Gap(8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/hamvpn_logo.png', width: 64, height: 64),
                  const Gap(16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.common.appTitle, style: Theme.of(context).textTheme.titleLarge),
                      const Gap(4),
                      Text("${t.common.version} ${appInfo.presentVersion}"),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              ...conditionalTiles,
              if (conditionalTiles.isNotEmpty) const Divider(),
              // ХамВПН: свои ссылки и документы прямо в приложении
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: const Text('Перейти на официальный сайт'),
                subtitle: const Text('hamvpn.net'),
                trailing: const Icon(FluentIcons.open_24_regular),
                onTap: () async => UriUtils.tryLaunch(Uri.parse(kHamSiteUrl)),
              ),
              if (kHamTelegramChannelUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.campaign_rounded),
                  title: const Text('Мы в Telegram'),
                  subtitle: const Text('@hamvpn13_bot — поддержка, баланс, новости'),
                  trailing: const Icon(FluentIcons.open_24_regular),
                  onTap: () async => UriUtils.tryLaunch(Uri.parse(kHamTelegramChannelUrl)),
                ),
              ListTile(
                leading: const Icon(Icons.gavel_rounded),
                title: const Text('Условия использования'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => HamInfoPage.open(context, HamInfo.terms),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_rounded),
                title: const Text('Политика конфиденциальности'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => HamInfoPage.open(context, HamInfo.privacy),
              ),
              const Divider(),
              // Требование лицензии Hiddify: указать, что приложение основано на нём, и дать ссылку на лицензию
              ListTile(
                dense: true,
                title: const Text('Основано на открытом проекте Hiddify'),
                subtitle: const Text('Лицензия GPL v3 с дополнительными условиями'),
                onTap: () async => UriUtils.tryLaunch(Uri.parse(Constants.licenseUrl)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
