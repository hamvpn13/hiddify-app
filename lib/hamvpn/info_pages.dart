import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/hamvpn/hamvpn_theme.dart';

/// Документы прямо в приложении (тексты — как на странице /policy сайта).
enum HamInfo { terms, privacy }

class _Section {
  const _Section(this.title, this.paragraphs);
  final String title;
  final List<String> paragraphs;
}

const _terms = [
  _Section('Условия использования', [
    'Сервис Хам VPN предоставляется «как есть», для личного некоммерческого использования.',
    'Одна конфигурация предназначена строго для одного устройства.',
  ]),
  _Section('Оплата', [
    'Оплата производится картой онлайн или через СБП на защищённой странице платёжного сервиса; '
        'баланс пополняется автоматически.',
    'Стоимость списывается с баланса посуточно. Пополнить баланс можно в приложении, на сайте hamvpn.net или в Telegram-боте.',
  ]),
  _Section('Приостановка и хранение данных', [
    'При исчерпании баланса конфигурация приостанавливается; данные хранятся 60 дней после приостановки, '
        'после чего удаляются без возможности восстановления.',
  ]),
];

const _privacy = [
  _Section('Политика конфиденциальности', [
    'Мы не ведём и не храним журналы посещаемых сайтов и содержимого трафика пользователей.',
    'В целях технической диагностики хранится только агрегированная статистика объёма трафика по конфигурации '
        '(сколько данных передано), без привязки к посещённым адресам.',
  ]),
  _Section('Пароли и учётные данные', [
    'Пароли пользователей хранятся в хешированном виде и никогда не передаются и не хранятся в открытом тексте.',
    'Учётные данные (логин, баланс, привязанный Telegram ID) используются исключительно для работы сервиса '
        'и не передаются третьим лицам.',
  ]),
  _Section('Приложение', [
    'Приложение не собирает статистику использования и не отправляет её сторонним сервисам. '
        'Журнал работы хранится только на вашем телефоне и отправляется в поддержку, только если вы сами им поделитесь.',
  ]),
];

class HamInfoPage extends StatelessWidget {
  const HamInfoPage({super.key, required this.info});

  final HamInfo info;

  static Future<void> open(BuildContext context, HamInfo info) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HamInfoPage(info: info)));

  @override
  Widget build(BuildContext context) {
    final k = HamTokens.of(context);
    final (title, sections) = switch (info) {
      HamInfo.terms => ('Условия использования', _terms),
      HamInfo.privacy => ('Конфиденциальность', _privacy),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 40),
        children: [
          for (final s in sections)
            HamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: TextStyle(color: k.text, fontSize: 18, fontWeight: FontWeight.w700)),
                  const Gap(10),
                  for (final p in s.paragraphs) ...[
                    Text(p, style: TextStyle(color: k.text, fontSize: 15, height: 1.55)),
                    const Gap(8),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
