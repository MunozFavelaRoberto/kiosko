class AuthResponse {
  final String msg;
  final AuthData data;

  AuthResponse({
    required this.msg,
    required this.data,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      msg: json['msg'] as String,
      data: AuthData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'msg': msg,
      'data': data.toJson(),
    };
  }
}

class AuthData {
  final Auth auth;

  AuthData({
    required this.auth,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      auth: Auth.fromJson(json['auth'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auth': auth.toJson(),
    };
  }
}

class Auth {
  final String token;
  final UserData user;

  Auth({
    required this.token,
    required this.user,
  });

  factory Auth.fromJson(Map<String, dynamic> json) {
    return Auth(
      token: json['token'] as String,
      user: UserData.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
    };
  }
}

class UserData {
  final int id;
  final String name;
  final String? paternalSurname;
  final String? maternalSurname;
  final String email;
  final int roleId;
  final String uiid;
  final String fullName;
  final Role role;

  UserData({
    required this.id,
    required this.name,
    this.paternalSurname,
    this.maternalSurname,
    required this.email,
    required this.roleId,
    required this.uiid,
    required this.fullName,
    required this.role,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] as int,
      name: json['name'] as String,
      paternalSurname: json['paternal_surname'] as String?,
      maternalSurname: json['maternal_surname'] as String?,
      email: json['email'] as String,
      roleId: json['role_id'] as int,
      uiid: json['uiid'] as String,
      fullName: json['full_name'] as String,
      role: Role.fromJson(json['role'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'paternal_surname': paternalSurname,
      'maternal_surname': maternalSurname,
      'email': email,
      'role_id': roleId,
      'uiid': uiid,
      'full_name': fullName,
      'role': role.toJson(),
    };
  }
}

class Role {
  final String name;

  Role({
    required this.name,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
    };
  }
}