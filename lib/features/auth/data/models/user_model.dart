import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_learn/features/auth/domain/entities/app_user.dart';

/// Firebase の User を Domain の AppUser に変換するモデル
///
/// Freezed クラス（AppUser）は継承できないため、
/// 変換メソッド toEntity() を持つ独立クラスとして定義する。
/// Data 層のみが知るクラスで、Domain 層には登場しない。
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  /// Firebase の User から UserModel を生成するファクトリ
  factory UserModel.fromFirebaseUser(User firebaseUser) {
    return UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
    );
  }

  /// Domain Entity（AppUser）に変換する
  /// RepositoryImpl がこのメソッドを呼んで Domain 層に渡す
  AppUser toEntity() {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }
}
