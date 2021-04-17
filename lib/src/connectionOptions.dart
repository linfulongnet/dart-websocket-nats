import 'dart:convert';

import 'serverInfo.dart';

/// Options for establishing server connection
class ConnectionOptions {
  /// Turns on +OK protocol acknowledgements
  bool? verbose;

  /// Turns on additional strict format checking, e.g. for properly formed subjects
  bool? pedantic;

  /// Indicates whether the client requires an SSL connection
  bool? tlsRequired;

  /// Client authorization token (if [ServerInfo.authRequired] is set)
  String? authToken;

  /// Connection username (if [ServerInfo.authRequired] is set)
  String? userName;

  /// Connection password (if [ServerInfo.authRequired] is set)
  String? password;

  /// Optional client name
  String? name;

  /// Language implementation of the client
  String? language;

  /// Version of the client
  String? version;

  /// Sending `0` (or absent) indicates client supports original protocol. Sending `1` indicates that the client supports dynamic reconfiguration of cluster topology changes by asynchronously receiving `INFO` messages with known servers it can reconnect to.
  int? protocol;

  /// If set to [true], the server (version 1.2.0+) will not send originating messages from this connection to its own subscriptions. Clients should set this to true only for server supporting this feature, which is when [protocol] in the `INFO` protocol is set to at least `1`
  bool? echo;

  ConnectionOptions({
    this.verbose,
    this.pedantic,
    this.tlsRequired,
    this.authToken,
    this.userName,
    this.password,
    this.name,
    this.language,
    this.version,
    this.protocol,
    this.echo,
  });

  void fromMap(Map<String, dynamic> map) {
    verbose = map["verbose"];
    pedantic = map["pedantic"];
    tlsRequired = map["tlsRequired"];
    authToken = map["authToken"];
    userName = map["userName"];
    password = map["password"];
    name = map["name"];
    language = map["language"];
    version = map["version"];
    protocol = map["protocol"];
    echo = map["echo"];
  }

  void fromJson(String str) {
    try {
      Map<String, dynamic> map = jsonDecode(str);
      fromMap(map);
    } catch (ex) {
      print('ConnectionOptions fromJson err: ' + ex.toString());
    }
  }

  String toJson() {
    Map<String, dynamic> map = {};
    map["verbose"] = verbose;
    map["pedantic"] = pedantic;
    map["tlsRequired"] = tlsRequired;
    map["authToken"] = authToken;
    map["userName"] = userName;
    map["password"] = password;
    map["name"] = name;
    map["language"] = language;
    map["version"] = version;
    map["protocol"] = protocol;
    map["echo"] = echo;

    return jsonEncode(_removeJsonNull(map));
  }
}

Map<String, dynamic> _removeJsonNull(Map<String, dynamic> map) {
  Map<String, dynamic> data = {};
  map.forEach((key, value) {
    if (value != null) data[key] = value;
  });

  return data;
}
