import 'package:flutter/material.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/deep_linking/my_app_links.dart';
import 'package:hiddify/hamvpn/hamvpn_account.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// For temporary storage of the link received from AppLinks.
String newUrlFromAppLink = '';

class RefreshListenable extends ChangeNotifier {
  RefreshListenable(this.ref) {
    ref.listen(myAppLinksProvider, (_, next) {
      if (next.value != null) {
        newUrlFromAppLink = next.value!;
        notifyListeners();
      }
    });
    ref.listen(Preferences.introCompleted, (_, _) => notifyListeners());
    // вход/выход из аккаунта ХамВПН переключает между экраном входа и главным
    ref.listen(HamPrefs.token, (_, _) => notifyListeners());
  }
  final Ref ref;
}
