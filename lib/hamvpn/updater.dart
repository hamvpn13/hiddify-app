import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/hamvpn/hamvpn_account.dart';
import 'package:hiddify/hamvpn/hamvpn_api.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Обновление приложения с нашего сайта hamvpn.net (не через Google Play).
///
/// Сайт отвечает на /api/app/v1/update, есть ли версия новее установленной,
/// и даёт ссылку на APK именно для процессора этого телефона. Приложение
/// скачивает файл само и открывает системный установщик — данные и вход сохраняются.
class HamUpdateInfo {
  HamUpdateInfo(Map<String, dynamic> d)
    : version = (d['version'] as String?) ?? '',
      build = ((d['build'] as num?) ?? 0).toInt(),
      notes = (d['notes'] as String?) ?? '',
      url = (d['url'] as String?) ?? '',
      size = ((d['size'] as num?) ?? 0).toInt(),
      force = d['force'] == true;

  final String version;
  final int build;
  final String notes;
  final String url;
  final int size;

  /// Обязательное обновление: старую версию больше нельзя использовать.
  final bool force;
}

abstract class HamUpdatePrefs {
  /// Номер сборки, которую человек отложил кнопкой «Позже» (напомним через сутки).
  static final skippedBuild = PreferencesNotifier.create<int, int>('hamvpn_update_skipped', 0);
  static final skippedAt = PreferencesNotifier.create<int, int>('hamvpn_update_skipped_at', 0);
}

const _channel = MethodChannel('com.hamvpn.app/update');

class HamUpdater {
  HamUpdater._();

  static DateTime? _lastAutoCheck;
  static bool _dialogOpen = false;

  /// Какой APK нужен этому устройству — тот же выбор, что и на странице скачивания.
  static Future<String> _abi() async {
    try {
      final abis = ((await _channel.invokeMethod<List<dynamic>>('abis')) ?? const []).cast<String>();
      final first = abis.isEmpty ? '' : abis.first;
      if (first == 'arm64-v8a') return 'arm64';
      if (first == 'armeabi-v7a') return 'arm7';
      if (first == 'x86_64') return 'x86_64';
    } catch (_) {}
    return 'universal';
  }

  static Future<int> currentBuild() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  static Future<HamUpdateInfo?> fetch(WidgetRef ref) async {
    final data = await ref.read(hamApiProvider).update(await _abi(), await currentBuild());
    if (data['available'] != true) return null;
    final info = HamUpdateInfo(data);
    return info.url.isEmpty ? null : info;
  }

  /// Тихая проверка при запуске и возврате в приложение (не чаще раза в 3 часа).
  static Future<void> autoCheck(BuildContext context, WidgetRef ref) async {
    if (!Platform.isAndroid || _dialogOpen) return;
    final now = DateTime.now();
    if (_lastAutoCheck != null && now.difference(_lastAutoCheck!) < const Duration(hours: 3)) return;
    _lastAutoCheck = now;
    try {
      final info = await fetch(ref);
      if (info == null || !context.mounted) return;
      if (!info.force) {
        final skipped = ref.read(HamUpdatePrefs.skippedBuild);
        final at = DateTime.fromMillisecondsSinceEpoch(ref.read(HamUpdatePrefs.skippedAt));
        if (skipped == info.build && now.difference(at) < const Duration(days: 1)) return;
      }
      await showOffer(context, ref, info);
    } catch (_) {
      // нет сети — проверим в следующий раз
    }
  }

  /// Кнопка «Проверить обновления» в «О программе».
  static Future<void> manualCheck(BuildContext context, WidgetRef ref) async {
    void snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
    try {
      final info = await fetch(ref);
      if (!context.mounted) return;
      if (info == null) {
        snack('У вас последняя версия');
        return;
      }
      await showOffer(context, ref, info);
    } on HamApiException catch (e) {
      if (context.mounted) snack(e.message);
    }
  }

  static Future<void> showOffer(BuildContext context, WidgetRef ref, HamUpdateInfo info) async {
    _dialogOpen = true;
    try {
      final mb = info.size > 0 ? ' · ${(info.size / 1024 / 1024).toStringAsFixed(0)} МБ' : '';
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: !info.force,
        builder: (ctx) => PopScope(
          canPop: !info.force,
          child: AlertDialog(
            icon: const Icon(Icons.system_update_rounded),
            title: Text(info.force ? 'Нужно обновить приложение' : 'Доступно обновление'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Версия ${info.version}$mb', style: Theme.of(ctx).textTheme.titleSmall),
                  if (info.notes.isNotEmpty) ...[const Gap(10), Text(info.notes)],
                  if (info.force) ...[
                    const Gap(10),
                    const Text('Эта версия устарела и может перестать подключаться. Обновление займёт минуту, вход и настройки сохранятся.'),
                  ],
                ],
              ),
            ),
            actions: [
              if (!info.force) TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Позже')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Обновить')),
            ],
          ),
        ),
      );
      if (ok == true) {
        if (context.mounted) await _downloadAndInstall(context, info);
      } else {
        await ref.read(HamUpdatePrefs.skippedBuild.notifier).update(info.build);
        await ref.read(HamUpdatePrefs.skippedAt.notifier).update(DateTime.now().millisecondsSinceEpoch);
      }
    } finally {
      _dialogOpen = false;
    }
  }

  static Future<void> _openInBrowser() =>
      launchUrl(Uri.parse('$kHamSiteUrl/download'), mode: LaunchMode.externalApplication);

  static Future<void> _downloadAndInstall(BuildContext context, HamUpdateInfo info) async {
    // Android просит один раз разрешить установку из этого приложения
    final can = await _channel.invokeMethod<bool>('canInstall').catchError((_) => true) ?? true;
    if (!can) {
      if (!context.mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Разрешите установку'),
          content: const Text(
            'Обновление скачивается с нашего сайта, поэтому Android один раз спросит разрешение. '
            'В открывшемся окне включите «Разрешить установку из этого источника» и вернитесь назад.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Открыть настройки')),
          ],
        ),
      );
      if (go != true) return;
      await _channel.invokeMethod<void>('openInstallSettings');
      // ждём, пока человек уйдёт в настройки и вернётся обратно
      final b = WidgetsBinding.instance;
      for (var i = 0; i < 10 && b.lifecycleState == AppLifecycleState.resumed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      for (var i = 0; i < 600 && b.lifecycleState != AppLifecycleState.resumed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final now = await _channel.invokeMethod<bool>('canInstall').catchError((_) => false) ?? false;
      if (!now) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Без разрешения обновить не получится. Можно скачать с сайта hamvpn.net/download')),
          );
        }
        return;
      }
    }
    if (!context.mounted) return;

    final progress = ValueNotifier<double?>(null);
    final cancel = CancelToken();
    String? error;
    String? path;

    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Скачиваем обновление'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, v, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: v),
                const Gap(10),
                Text(v == null ? 'Подключаемся к сайту…' : '${(v * 100).toStringAsFixed(0)}%'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancel.cancel();
                Navigator.pop(ctx);
              },
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    );

    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      path = '${dir.path}/HamVPN-${info.build}.apk';
      await Dio(BaseOptions(connectTimeout: const Duration(seconds: 20))).download(
        info.url,
        path,
        cancelToken: cancel,
        onReceiveProgress: (got, total) {
          final t = total > 0 ? total : info.size;
          if (t > 0) progress.value = got / t;
        },
      );
      final len = File(path).lengthSync();
      if (info.size > 0 && len != info.size) error = 'Файл скачался не полностью. Попробуйте ещё раз.';
    } on DioException catch (e) {
      error = CancelToken.isCancel(e) ? '' : 'Не удалось скачать обновление. Проверьте интернет и попробуйте ещё раз.';
    } catch (_) {
      error = 'Не удалось сохранить обновление на телефон.';
    }

    if (cancel.isCancelled) return;
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    await dialog;
    if (!context.mounted) return;

    if (error != null) {
      if (error.isEmpty) return;
      final retry = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Обновление не скачалось'),
          content: Text(error!),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'site'), child: const Text('Скачать на сайте')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'retry'), child: const Text('Повторить')),
          ],
        ),
      );
      if (retry == 'retry' && context.mounted) return _downloadAndInstall(context, info);
      if (retry == 'site') await _openInBrowser();
      return;
    }

    try {
      await _channel.invokeMethod<void>('install', {'path': path});
    } catch (_) {
      await _openInBrowser();
    }
  }
}
