import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:hiddify/core/analytics/analytics_controller.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hiddify/gorec/gorec_api.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Имя профиля, под которым подписка Горец видна внутри движка Hiddify.
const String kHamProfileName = 'Горец';

abstract class GorecPrefs {
  /// Токен входа в аккаунт Горец. Пустая строка — не вошли.
  static final token = PreferencesNotifier.create<String, String>('gorec_token', '');

  /// Ссылка подписки, которую приложение уже добавило в Hiddify.
  static final profileUrl = PreferencesNotifier.create<String, String>('gorec_profile_url', '');

  /// Логин — чтобы приветствие «Добрый день, …» было видно сразу при запуске.
  static final login = PreferencesNotifier.create<String, String>('gorec_login', '');
}

final gorecApiProvider = Provider<GorecApi>((ref) => GorecApi());

/// Состояние аккаунта: последний ответ /me (баланс, дни, конфигурации).
class GorecAccountState {
  const GorecAccountState({this.me, this.loading = false, this.error});

  final Map<String, dynamic>? me;
  final bool loading;
  final String? error;

  Map<String, dynamic> get user => Map<String, dynamic>.from((me?['user'] as Map?) ?? const {});
  Map<String, dynamic> get trial => Map<String, dynamic>.from((me?['trial'] as Map?) ?? const {});
  Map<String, dynamic> get links => Map<String, dynamic>.from((me?['links'] as Map?) ?? const {});

  String get login => (user['login'] as String?) ?? '';
  double get balanceRub => ((user['balance_rub'] as num?) ?? 0).toDouble();
  int get daysLeft => ((me?['days_left'] as num?) ?? 0).toInt();
  bool get trialActive => trial['active'] == true;
  int get pricePerMonth => ((me?['price_per_month_rub'] as num?) ?? 195).toInt();

  List<Map<String, dynamic>> get configs =>
      ((me?['configs'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  bool get hasActiveConfig => configs.any((c) => c['status'] == 'active');

  String link(String key) => (links[key] as String?) ?? '';

  GorecAccountState copyWith({Map<String, dynamic>? me, bool? loading, String? error, bool clearError = false}) =>
      GorecAccountState(
        me: me ?? this.me,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

final gorecAccountProvider = NotifierProvider<GorecAccountNotifier, GorecAccountState>(GorecAccountNotifier.new);

class GorecAccountNotifier extends Notifier<GorecAccountState> {
  @override
  GorecAccountState build() => const GorecAccountState();

  GorecApi get _api => ref.read(gorecApiProvider);
  String get _token => ref.read(GorecPrefs.token);

  String _deviceName() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'app';
    }
  }

  /// Первый вход на этом устройстве: русский язык, правила маршрутизации для России
  /// (российские сайты — напрямую, мимо VPN) и без вступительного экрана Hiddify.
  Future<void> _applyFirstLaunchDefaults() async {
    await ref.read(Preferences.introCompleted.notifier).update(true);
    await ref.read(ConfigOptions.region.notifier).update(Region.ru);
    try {
      await ref.read(localePreferencesProvider.notifier).changeLocale(AppLocale.ru);
    } catch (_) {}
    // Никакой статистики использования наружу (Hiddify по умолчанию шлёт отчёты об ошибках)
    try {
      await ref.read(analyticsControllerProvider.notifier).disableAnalytics();
    } catch (_) {}
  }

  Future<void> _afterAuth(Map<String, dynamic> data) async {
    final token = data['token'] as String? ?? '';
    state = GorecAccountState(me: data);
    await ref.read(GorecPrefs.login.notifier).update(state.login);
    // Сервер вход уже подтвердил — любая ошибка дальше (настройки, добавление
    // подписки) не должна оставлять человека на экране входа без ответа.
    try {
      await _applyFirstLaunchDefaults();
    } catch (e) {
      debugPrint('gorec: first-launch defaults failed: $e');
    }
    String? syncError;
    try {
      await syncProfile();
    } catch (e) {
      debugPrint('gorec: syncProfile failed: $e');
      syncError = 'Вход выполнен, но подписку не удалось добавить автоматически ($e). Она добавится при следующем запуске.';
    }
    if (syncError != null) state = state.copyWith(error: syncError);
    // Токен сохраняем последним: на него завязан переход на главный экран
    await ref.read(GorecPrefs.token.notifier).update(token);
  }

  Future<String?> login(String login, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await _api.login(login.trim(), password, _deviceName());
      await _afterAuth(data);
      return null;
    } on GorecApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return e.message;
    }
    catch (e) {
      debugPrint('gorec: auth failed: $e');
      final msg = 'Не удалось войти: $e';
      state = state.copyWith(loading: false, error: msg);
      return msg;
    }
  }

  Future<String?> register(String login, String password, {String? ref}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await _api.register(login.trim(), password, _deviceName(), ref: ref);
      await _afterAuth(data);
      return null;
    } on GorecApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return e.message;
    }
    catch (e) {
      debugPrint('gorec: auth failed: $e');
      final msg = 'Не удалось войти: $e';
      state = state.copyWith(loading: false, error: msg);
      return msg;
    }
  }

  /// Вход по одноразовой ссылке с сайта (кнопка «Открыть в приложении»).
  /// Если в приложении уже другой аккаунт — он заменяется тем, что на сайте.
  Future<String?> loginWithLink(String linkToken) async {
    if (linkToken.isEmpty) return 'Ссылка для входа устарела. Откройте её на сайте ещё раз.';
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await _api.loginByLink(linkToken, _deviceName());
      final newLogin = (Map<String, dynamic>.from((data['user'] as Map?) ?? const {})['login'] as String?) ?? '';
      final current = ref.read(GorecPrefs.login);
      if (_token.isNotEmpty && current.isNotEmpty && current != newLogin) {
        await logout(callServer: false);
      }
      await _afterAuth(data);
      return null;
    } on GorecApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return e.message;
    }
    catch (e) {
      debugPrint('gorec: auth failed: $e');
      final msg = 'Не удалось войти: $e';
      state = state.copyWith(loading: false, error: msg);
      return msg;
    }
  }

  /// Адрес личного кабинета на сайте с автоматическим входом.
  /// Если сайт не ответил — просто страница сайта (там можно войти вручную).
  Future<String> siteLoginUrl() async {
    final fallback = state.link('site').isNotEmpty ? state.link('site') : '$kHamSiteUrl/cabinet';
    final token = _token;
    if (token.isEmpty) return fallback;
    try {
      final data = await _api.webLoginLink(token);
      final url = data['url'] as String?;
      return (url == null || url.isEmpty) ? fallback : url;
    } on GorecApiException {
      return fallback;
    }
  }

  /// Обновить баланс и дни (при запуске, возврате в приложение, после оплаты).
  Future<void> refresh() async {
    final token = _token;
    if (token.isEmpty) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await _api.me(token);
      state = GorecAccountState(me: data);
      if (state.login.isNotEmpty && state.login != ref.read(GorecPrefs.login)) {
        await ref.read(GorecPrefs.login.notifier).update(state.login);
      }
      try {
        await syncProfile();
      } catch (e) {
        debugPrint('gorec: syncProfile failed: $e');
      }
    } on GorecApiException catch (e) {
      if (e.isUnauthorized) {
        await logout(callServer: false);
        return;
      }
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  /// Подписка аккаунта автоматически добавляется в движок и становится активной —
  /// человеку не нужно ничего копировать и вставлять.
  Future<void> syncProfile() async {
    final configs = state.configs;
    if (configs.isEmpty) return;
    Map<String, dynamic>? chosen;
    for (final c in configs) {
      if (c['status'] == 'active') {
        chosen = c;
        break;
      }
    }
    chosen ??= configs.first;
    final url = chosen['subscription_url'] as String?;
    if (url == null || url.isEmpty) return;

    final repo = await ref.read(profileRepositoryProvider.future);

    Future<RemoteProfileEntity?> findOurs() async {
      final all = await repo.watchAll().first;
      final list = all.getOrElse((_) => <ProfileEntity>[]);
      for (final p in list) {
        if (p is RemoteProfileEntity && p.url == url) return p;
      }
      return null;
    }

    var ours = await findOurs();
    if (ours == null) {
      await repo.upsertRemote(url, userOverride: const UserOverride(name: kHamProfileName)).run();
      ours = await findOurs();
    }
    if (ours != null && !ours.active) {
      await repo.setAsActive(ours.id).run();
    }
    if (ours != null) {
      await ref.read(GorecPrefs.profileUrl.notifier).update(url);
    }
  }

  Future<void> logout({bool callServer = true}) async {
    final token = _token;
    if (callServer && token.isNotEmpty) await _api.logout(token);
    try {
      await ref.read(connectionNotifierProvider.notifier).abortConnection();
    } catch (_) {}
    // Убираем подписку аккаунта с устройства — следующий человек войдёт под своим
    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      final all = await repo.watchAll().first;
      final list = all.getOrElse((_) => <ProfileEntity>[]);
      final ourUrl = ref.read(GorecPrefs.profileUrl);
      for (final p in list) {
        if (p is RemoteProfileEntity && (p.url == ourUrl || p.url.startsWith(kHamSiteUrl))) {
          await repo.deleteById(p.id, p.active).run();
        }
      }
    } catch (_) {}
    await ref.read(GorecPrefs.profileUrl.notifier).update('');
    await ref.read(GorecPrefs.login.notifier).update('');
    state = const GorecAccountState();
    await ref.read(GorecPrefs.token.notifier).update('');
  }

  Future<List<Map<String, dynamic>>> plans() async {
    final data = await _api.plans(_token);
    return ((data['plans'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> payMethods() async {
    final data = await _api.plans(_token);
    return ((data['methods'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Возвращает (ссылка на оплату, номер заявки).
  Future<(String, int)> createTopup(int months, String method) async {
    final data = await _api.topup(_token, months, method);
    return (data['payment_url'] as String, (data['request_id'] as num).toInt());
  }

  Future<String> topupStatus(int requestId) async {
    final data = await _api.topupStatus(_token, requestId);
    return (data['status'] as String?) ?? 'pending';
  }

  Future<Map<String, dynamic>> referral() => _api.referral(_token);

  Future<String> referralTransfer() async {
    final data = await _api.referralTransfer(_token);
    await refresh();
    return (data['message'] as String?) ?? 'Готово';
  }

  Future<String> referralPayout(String amount, String details) async {
    final data = await _api.referralPayout(_token, amount, details);
    return (data['message'] as String?) ?? 'Заявка создана';
  }

  Future<String> redeemPromo(String code) async {
    final data = await _api.promo(_token, code);
    state = GorecAccountState(me: data);
    return (data['message'] as String?) ?? 'Промокод активирован!';
  }
}
