import "auth/auth.dart";
import "core/core.dart";
import "query/query.dart";
import "error/error.dart";

class Message {
  Core core;
  Auth auth;
  Query query;
  Error error;

  Message(this.core, {this.auth, this.error, this.query});

  Map toJson() => {
        if (core != null) "core": core.toJson(),
        if (auth != null) "auth": auth.toJson(),
        if (error != null) "error": error.toJson(),
        if (query != null) "query": query.toJson()
      };
  factory Message.fromJson(dynamic json) {
    return Message(json["core"] != null ? Core.fromJson(json["core"]) : null,
        auth: json["auth"] != null ? Auth.fromJson(json["auth"]) : null,
        error: json["error"] != null ? Error.fromJson(json["error"]) : null,
        query: json["query"] != null ? Query.fromJson(json["query"]) : null);
  }
}
