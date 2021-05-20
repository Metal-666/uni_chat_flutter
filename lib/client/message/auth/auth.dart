class Auth {
  String username;
  String password;

  Auth({this.username, this.password});

  Map toJson() => {"username": username, "password": password};

  factory Auth.fromJson(dynamic json) {
    return Auth(username: json["username"], password: json["password"]);
  }
}
