import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.displayName,
    this.email,
  });

  factory UserProfile.empty() => const UserProfile(
        displayName: 'choice user',
      );

  final String displayName;
  final String? email;

  UserProfile copyWith({
    String? displayName,
    String? email,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
    );
  }

  @override
  List<Object?> get props => [displayName, email];
}


