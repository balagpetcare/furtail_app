import '../../../../core/storage/local_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl {
  final AuthRemoteDataSource remote;
  AuthRepositoryImpl(this.remote);

  Future<UserEntity> login({
    required String identifier,
    required String password,
  }) async {
    final data = await remote.login(identifier: identifier, password: password);

    // ✅ Assumption: { success:true, token:"", user:{...} }
    final token = data['token']?.toString() ?? '';
    final userJson = data['user'];

    if (token.isEmpty || userJson is! Map<String, dynamic>) {
      throw Exception(data['message']?.toString() ?? 'Invalid login response');
    }

    final user = UserModel.fromJson(userJson);

    await LocalStorage.saveAuth(
      token: token,
      userName: user.name,
      userEmail: user.email,
      userId: user.id,
    );

    return user;
  }

  Future<void> register({
    required String name,
    required String identifier,
    required String password,
  }) async {
    await remote.register(name: name, identifier: identifier, password: password);
  }

  Future<UserEntity> loginWithGoogle({required String idToken}) async {
    final data = await remote.loginWithGoogle(idToken: idToken);

    final token = data['token']?.toString() ?? '';
    final userJson = data['user'];

    if (token.isEmpty || userJson is! Map<String, dynamic>) {
      throw Exception(
        data['message']?.toString() ?? 'Invalid Google login response',
      );
    }

    final user = UserModel.fromJson(userJson);
    await LocalStorage.saveAuth(
      token: token,
      userName: user.name,
      userEmail: user.email,
      userId: user.id,
    );
    return user;
  }

  Future<UserEntity> loginWithFacebook({required String accessToken}) async {
    final data = await remote.loginWithFacebook(accessToken: accessToken);

    final token = data['token']?.toString() ?? '';
    final userJson = data['user'];

    if (token.isEmpty || userJson is! Map<String, dynamic>) {
      throw Exception(
        data['message']?.toString() ?? 'Invalid Facebook login response',
      );
    }

    final user = UserModel.fromJson(userJson);
    await LocalStorage.saveAuth(
      token: token,
      userName: user.name,
      userEmail: user.email,
      userId: user.id,
    );
    return user;
  }
}
