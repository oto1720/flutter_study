import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_learn/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:flutter_learn/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';
import 'package:flutter_learn/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_learn/features/auth/domain/usecases/get_current_user.dart';
import 'package:flutter_learn/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:flutter_learn/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:flutter_learn/features/auth/domain/usecases/sign_out.dart';
import 'package:flutter_learn/features/auth/domain/usecases/sign_up_with_email.dart';

part 'auth_providers.g.dart';

// ---------------------------------------------------------------------------
// インフラ層（Firebase SDK インスタンス）
// ---------------------------------------------------------------------------

@riverpod
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

@riverpod
GoogleSignIn googleSignIn(Ref ref) => GoogleSignIn();

// ---------------------------------------------------------------------------
// Data層
// ---------------------------------------------------------------------------

@riverpod
AuthRemoteDataSource authRemoteDataSource(Ref ref) =>
    AuthRemoteDataSourceImpl(
      ref.watch(firebaseAuthProvider),
      ref.watch(googleSignInProvider),
    );

@riverpod
AuthRepository authRepository(Ref ref) =>
    AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));

// ---------------------------------------------------------------------------
// Stream: Firebase の認証状態をリアルタイム監視
// ---------------------------------------------------------------------------

@riverpod
Stream<AppUser?> authStateChanges(Ref ref) =>
    ref.watch(authRepositoryProvider).authStateChanges;

// ---------------------------------------------------------------------------
// UseCase 群
// ---------------------------------------------------------------------------

@riverpod
SignInWithEmail signInWithEmailUseCase(Ref ref) =>
    SignInWithEmail(ref.watch(authRepositoryProvider));

@riverpod
SignInWithGoogle signInWithGoogleUseCase(Ref ref) =>
    SignInWithGoogle(ref.watch(authRepositoryProvider));

@riverpod
SignUpWithEmail signUpWithEmailUseCase(Ref ref) =>
    SignUpWithEmail(ref.watch(authRepositoryProvider));

@riverpod
SignOut signOutUseCase(Ref ref) =>
    SignOut(ref.watch(authRepositoryProvider));

@riverpod
GetCurrentUser getCurrentUserUseCase(Ref ref) =>
    GetCurrentUser(ref.watch(authRepositoryProvider));
