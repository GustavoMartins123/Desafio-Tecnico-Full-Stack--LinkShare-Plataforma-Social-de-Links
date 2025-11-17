class AuthResponse {
  final String token;
  final int userId;
  final String username;
  final String email;

  AuthResponse({
    required this.token,
    required this.userId,
    required this.username,
    required this.email,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      userId: json['userId'],
      username: json['username'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'userId': userId,
      'username': username,
      'email': email,
    };
  }
}
