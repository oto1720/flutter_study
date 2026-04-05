import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_learn/core/error/failure.dart';
import 'package:flutter_learn/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_learn/features/auth/domain/repositories/auth_repository.dart';

/// AuthRepository の Firebase 実装
///
/// 責務：
/// 1. DataSource を呼び出す
/// 2. FirebaseAuthException を Failure（Either の Left）に変換する
/// 3. try/catch はこのクラスにのみ存在する（上位層に例外を届けない）
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _dataSource;

  const AuthRepositoryImpl(this._dataSource);

  @override
  Stream<AppUser?> get authStateChanges {
    return _dataSource.authStateChanges.map(
      (model) => model?.toEntity(),
    );
  }

  @override
  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final model = await _dataSource.signInWithEmail(
        email: email,
        password: password,
      );
      return Right(model.toEntity());
    } on FirebaseAuthException catch (e) {
      return Left(Failure.auth(message: e.message ?? '', code: e.code));
    } on Exception {
      return const Left(Failure.unexpected());
    }
  }

  @override
  Future<Either<Failure, AppUser>> signInWithGoogle() async {
    try {
      final model = await _dataSource.signInWithGoogle();
      return Right(model.toEntity());
    } on FirebaseAuthException catch (e) {
      return Left(Failure.auth(message: e.message ?? '', code: e.code));
    } on Exception {
      return const Left(Failure.unexpected());
    }
  }

  @override
  Future<Either<Failure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final model = await _dataSource.signUpWithEmail(
        email: email,
        password: password,
      );
      return Right(model.toEntity());
    } on FirebaseAuthException catch (e) {
      return Left(Failure.auth(message: e.message ?? '', code: e.code));
    } on Exception {
      return const Left(Failure.unexpected());
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _dataSource.signOut();
      return const Right(unit);
    } on Exception {
      return const Left(Failure.unexpected());
    }
  }

  @override
  Future<Either<Failure, AppUser>> getCurrentUser() async {
    try {
      final model = await _dataSource.getCurrentUser();
      if (model == null) {
        return const Left(
          Failure.auth(message: 'No user is signed in.', code: 'no-current-user'),
        );
      }
      return Right(model.toEntity());
    } on Exception {
      return const Left(Failure.unexpected());
    }
  }
}
