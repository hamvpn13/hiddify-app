import 'package:dio/dio.dart';

/// Адрес сайта ХамВПН. Приложение — ещё одно окно к тому же аккаунту,
/// что сайт и бот: тот же логин, баланс, конфигурации и оплата.
const String kHamSiteUrl = 'https://hamvpn.net';
const String kHamApiBase = '$kHamSiteUrl/api/app/v1';

/// Telegram-канал ХамВПН (пусто — пункт в «О программе» не показывается).
const String kHamTelegramChannelUrl = '';

/// Ошибка API с текстом, который можно сразу показать человеку.
class HamApiException implements Exception {
  HamApiException(this.message, {this.code = 'error', this.status});

  final String message;
  final String code;
  final int? status;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// Тонкий клиент к /api/app/v1 на сайте (см. app/routes/app_api.py на сервере).
class HamApi {
  HamApi()
    : _dio = Dio(
        BaseOptions(
          baseUrl: kHamApiBase,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json'},
          // Ошибки 4xx разбираем сами — в них лежит понятный текст для человека
          validateStatus: (status) => status != null && status < 600,
        ),
      );

  final Dio _dio;

  Options _auth(String token) => Options(headers: {'Authorization': 'Bearer $token'});

  Future<Map<String, dynamic>> _call(Future<Response<dynamic>> Function() request) async {
    final Response<dynamic> response;
    try {
      response = await request();
    } on DioException catch (e) {
      final timeout =
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      throw HamApiException(
        timeout
            ? 'Сервер долго не отвечает. Проверьте интернет и попробуйте ещё раз.'
            : 'Нет связи с сервером ХамВПН. Проверьте интернет и попробуйте ещё раз.',
        code: 'network',
      );
    }
    final data = response.data;
    if (data is! Map) {
      throw HamApiException('Сервер вернул неожиданный ответ. Попробуйте позже.', status: response.statusCode);
    }
    final map = Map<String, dynamic>.from(data);
    if (map['ok'] != true) {
      throw HamApiException(
        (map['error'] as String?) ?? 'Что-то пошло не так. Попробуйте ещё раз.',
        code: (map['code'] as String?) ?? 'error',
        status: response.statusCode,
      );
    }
    return map;
  }

  Future<Map<String, dynamic>> login(String login, String password, String device) =>
      _call(() => _dio.post('/login', data: {'login': login, 'password': password, 'device': device}));

  Future<Map<String, dynamic>> register(String login, String password, String device, {String? ref}) => _call(
    () => _dio.post(
      '/register',
      data: {'login': login, 'password': password, 'device': device, if (ref != null && ref.isNotEmpty) 'ref': ref},
    ),
  );

  Future<Map<String, dynamic>> me(String token) => _call(() => _dio.get('/me', options: _auth(token)));

  Future<Map<String, dynamic>> plans(String token) => _call(() => _dio.get('/plans', options: _auth(token)));

  Future<Map<String, dynamic>> topup(String token, int months, String method) =>
      _call(() => _dio.post('/topup', data: {'months': months, 'method': method}, options: _auth(token)));

  Future<Map<String, dynamic>> topupStatus(String token, int requestId) =>
      _call(() => _dio.get('/topup/$requestId', options: _auth(token)));

  Future<Map<String, dynamic>> promo(String token, String code) =>
      _call(() => _dio.post('/promo', data: {'code': code}, options: _auth(token)));

  Future<void> logout(String token) async {
    try {
      await _dio.post('/logout', options: _auth(token));
    } catch (_) {
      // выход локально происходит в любом случае
    }
  }
}
