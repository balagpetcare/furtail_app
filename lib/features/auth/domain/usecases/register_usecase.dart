import '../../data/repositories/auth_repository_impl.dart';

class RegisterUseCase {
  final AuthRepositoryImpl repo;
  RegisterUseCase(this.repo);

  /// Register by phone (backend expects 'phone')
  /// UI collects email/phone together; we pass the identifier and datasource
  /// will send email/phone accordingly.
  Future<void> execute({
    required String name,
    required String identifier,
    required String password,
  }) {
    return repo.register(
      name: name,
      identifier: identifier,
      password: password,
    );
  }
}
