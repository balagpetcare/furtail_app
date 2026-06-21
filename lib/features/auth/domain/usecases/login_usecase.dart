import '../entities/user_entity.dart';
import '../../data/repositories/auth_repository_impl.dart';

class LoginUseCase {
  final AuthRepositoryImpl repo;
  LoginUseCase(this.repo);

  Future<UserEntity> execute({
    required String identifier, // email or phone
    required String password,
  }) {
    return repo.login(identifier: identifier, password: password);
  }
}
