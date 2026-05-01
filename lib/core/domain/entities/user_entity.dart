import 'package:flutter/foundation.dart';

@immutable
class UserEntity {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isAnonymous;

  const UserEntity({
    required this.uid,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });
}
