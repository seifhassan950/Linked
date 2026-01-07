import 'dart:html' as html;

import 'token_store_impl.dart';

class TokenStoreImpl implements TokenStore {
  static const _kAccess = 'r2v_access_token';
  static const _kRefresh = 'r2v_refresh_token';

  @override
  Future<String?> getAccessToken() async => html.window.localStorage[_kAccess];

  @override
  Future<String?> getRefreshToken() async => html.window.localStorage[_kRefresh];

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    html.window.localStorage[_kAccess] = accessToken;
    html.window.localStorage[_kRefresh] = refreshToken;
  }

  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_kAccess);
    html.window.localStorage.remove(_kRefresh);
  }
}
