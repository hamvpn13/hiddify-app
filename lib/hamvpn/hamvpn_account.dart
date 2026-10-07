import 'dart:io';

import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hiddify/hamvpn/hamvpn_api.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Имя профиля, под которым подписка ХамВПН видна внутри движка Hiddify.
const String kHamProfileName = 'ХамВПН';

abstract class HamPrefs {
  /// Токен входа в аккаунт ХамВПН. Пустая строка — не вошли.
  static final token = PreferencesNotifier.create<String, String>('hamvpn_token', '');

  /// Ссылка подписки, которую приложение уже добавило в Hiddify.
  static final profileUrl = PreferencesNotifier.create<String, String>('hamvpn_profile_url', '');
}

final hamApiProvider = Provider<HamApi>((ref) => HamApi());

/// Состояние аккаунта: последний ответ /me (баланс, дни, конфигурации).
class HamAccountState {
  const HamAccountState({this.me, this.loading = false, this.error});

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

  HamAccountState copyWith({Map<String, dynamic>? me, bool? loading, String? error, bool clearError = false}) =>
      HamAccountState(
        me: me ?? this.me,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

final hamAccountProvider = NotifierProvider<HamAccountNotifier, HamAccountState>(HamAccountNotifier.new);

class HamAccountNotifier extends Notifier<HamAccountState> {
  @override
  HamAccountState build() => const HamAccountState();

  HamApi get _api => ref.read(hamApiProvider);
  String get _token => ref.read(HamPrefs.token);

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
  }

  Future<void> _afterAuth(Map<String, dynamic> data) async {
    final token = data['token'] as String? ?? '';
    state = HamAccountState(me: data);
    await _applyFirstLaunchDefaults();
    await syncProfile();
    // Токен сохраняем последним: на него завязан переход на главный экран
    await ref.read(HamPrefs.token.notifier).update(token);
  }

  Future<String?> login(String login, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await _api.login(login.trim(), password, _deviceName());
      await _afterAuth(data);
      return null;
    } on HamApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return e.message;
    }
  }

  Future<String?> register(String login, String password, {String? ref}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await _api.register(login.trim(), password, _deviceName(), ref: ref);
      await _afterAuth(data);
      return null;
    } on HamApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return e.message;
    }
  }

  /// Обновить баланс и дни (при запуске, возврате в приложение, после оплаты).
  Future<void> refresh() async {
    final token = _token;
    if (token.isEmpty) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await _api.me(token);
      state = HamAccountState(me: data);
      await syncProfile();
    } on HamApiException catch (e) {
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
      await ref.read(HamPrefs.profileUrl.notifier).update(url);
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
      final ourUrl = ref.read(HamPrefs.profileUrl);
      for (final p in list) {
        if (p is RemoteProfileEntity && (p.url == ourUrl || p.url.startsWith(kHamSiteUrl))) {
          await repo.deleteById(p.id, p.active).run();
        }
      }
    } catch (_) {}
    await ref.read(HamPrefs.profileUrl.notifier).update('');
    state = const HamAccountState();
    await ref.read(HamPrefs.token.notifier).update('');
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

  Future<String> redeemPromo(String code) async {
    final data = await _api.promo(_token, code);
    state = HamAccountState(me: data);
    return (data['message'] as String?) ?? 'Промокод активирован!';
  }
}
