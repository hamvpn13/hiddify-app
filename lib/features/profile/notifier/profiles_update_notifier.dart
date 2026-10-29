import 'package:dartx/dartx.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/gorec/gorec_account.dart';
import 'package:hiddify/gorec/gorec_api.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:meta/meta.dart';
import 'package:neat_periodic_task/neat_periodic_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profiles_update_notifier.g.dart';

typedef ProfileUpdateStatus = ({String name, bool success});

@Riverpod(keepAlive: true)
class ForegroundProfilesUpdateNotifier extends _$ForegroundProfilesUpdateNotifier with AppLogger {
  static const prefKey = "profiles_update_check";
  /// Как часто просыпается проверка. Для подписки Горец этого же интервала
  /// достаточно: список серверов (названия, новые страны) подтягивается сам.
  static const interval = Duration(minutes: 10);

  /// Интервал обновления подписки Горец — вместо 12 часов из заголовка Marzban.
  static const gorecInterval = Duration(minutes: 10);

  /// Подписка нашего аккаунта (добавлена приложением автоматически).
  bool _isHamProfile(RemoteProfileEntity profile) {
    final ours = ref.read(GorecPrefs.profileUrl);
    return (ours.isNotEmpty && profile.url == ours) || profile.url.startsWith(kHamSiteUrl);
  }

  @override
  Stream<ProfileUpdateStatus?> build() {
    var cycleCount = 0;
    _scheduler = NeatPeriodicTaskScheduler(
      name: 'profiles update worker',
      interval: interval,
      timeout: const Duration(minutes: 5),
      task: () async {
        loggy.debug("cycle [${cycleCount++}]");
        await updateProfiles();
      },
    );

    ref.onDispose(() async {
      await _scheduler?.stop();
      _scheduler = null;
    });

    if (ref.watch(Preferences.introCompleted)) {
      loggy.debug("intro done, starting");
      _scheduler?.start();
    } else {
      loggy.debug("intro in process, skipping");
    }
    return const Stream.empty();
  }

  NeatPeriodicTaskScheduler? _scheduler;
  bool _forceNextRun = false;

  Future<void> trigger() async {
    loggy.debug("triggering update");
    _forceNextRun = true;
    await _scheduler?.trigger();
  }

  @visibleForTesting
  Future<void> updateProfiles() async {
    var force = false;
    if (_forceNextRun) {
      force = true;
      _forceNextRun = false;
    }

    try {
      final previousRun = DateTime.tryParse(ref.read(sharedPreferencesProvider).requireValue.getString(prefKey) ?? "");

      if (!force && previousRun != null && previousRun.add(interval) > DateTime.now()) {
        loggy.debug("too soon! previous run: [$previousRun]");
        return;
      }
      loggy.debug("${force ? "[FORCED] " : ""}running, previous run: [$previousRun]");

      final remoteProfiles = await ref
          .read(profileRepositoryProvider)
          .requireValue
          .watchAll()
          .map(
            (event) => event.getOrElse((f) {
              loggy.error("error getting profiles");
              throw f;
            }).whereType<RemoteProfileEntity>(),
          )
          .first;

      await for (final profile in Stream.fromIterable(remoteProfiles)) {
        final isHam = _isHamProfile(profile);
        // Горец: обновляем тихо, раз в 10 минут. Подключение при этом не
        // перезапускается — новый список серверов применится при следующем
        // подключении, интернет у человека не прерывается.
        final updateInterval = isHam ? gorecInterval : profile.options?.updateInterval;
        // небольшой запас, чтобы не пропускать цикл из-за пары секунд разницы
        final due =
            updateInterval != null &&
            updateInterval - const Duration(seconds: 30) <= DateTime.now().difference(profile.lastUpdate);
        if (isHam && (force || due)) {
          await ref
              .read(profileRepositoryProvider)
              .requireValue
              .upsertRemote(profile.url)
              .mapLeft((l) => loggy.debug("gorec: silent update failed [${profile.id}]", l))
              .map((_) => loggy.debug("gorec: subscription refreshed [${profile.id}]"))
              .run();
          continue;
        }
        if (force || due) {
          final t = ref.read(translationsProvider).requireValue;
          await ref
              .read(profileRepositoryProvider)
              .requireValue
              .upsertRemote(profile.url)
              .mapLeft((l) {
                loggy.debug("error updating profile [${profile.id}]", l);
                ref
                    .read(inAppNotificationControllerProvider)
                    .showErrorToast(t.pages.profiles.msg.update.failureNamed(name: profile.name));
                state = AsyncData((name: profile.name, success: false));
              })
              .map((_) {
                loggy.debug("profile [${profile.id}] updated successfully");
                ref
                    .read(inAppNotificationControllerProvider)
                    .showSuccessToast(t.pages.profiles.msg.update.successNamed(name: profile.name));
                state = AsyncData((name: profile.name, success: true));
              })
              .run();
        } else {
          loggy.debug(
            "skipping profile [${profile.id}] update. last successful update: [${profile.lastUpdate}] - interval: [${profile.options?.updateInterval}]",
          );
        }
      }
    } finally {
      await ref.read(sharedPreferencesProvider).requireValue.setString(prefKey, DateTime.now().toIso8601String());
    }
  }
}
