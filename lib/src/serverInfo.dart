import 'dart:convert';

class ServerInfo {
  String? serverId;
  // nats version
  String? version;
  // go version
  String? go;
  // protocol version
  int? proto;
  String? host;
  int? port;
  int? maxPayload;
  int? clientId;
  bool? authRequired;
  bool? tlsRequired;
  bool? tlsVerify;
  List<String>? serverUrls;

  ServerInfo({
    this.serverId,
    this.version,
    this.go,
    this.proto,
    this.host,
    this.port,
    this.maxPayload,
    this.clientId,
    this.authRequired,
    this.tlsRequired,
    this.tlsVerify,
    this.serverUrls
  });

   void fromMap(Map<String, dynamic> map) {
      serverId = map["server_id"];
      version = map["version"];
      go = map["go"];
      proto = map["proto"];
      host = map["host"];
      port = map["port"];
      maxPayload = map["max_payload"];
      clientId = map["client_id"];
      authRequired = map["auth_required"];
      tlsRequired = map["tlsequired"];
      tlsVerify = map["tls_verify"];
      if(map["connect_urls"] != null) serverUrls = map["connect_urls"].cast<String>();
  }

  void fromJson(String str) {
    try {
      Map<String, dynamic> map = jsonDecode(str);
      fromMap(map);
    } catch (ex) {
      print('ServerInfo fromJson err: ' + ex.toString());
    }
  }

  String toJson() {
    Map<String, dynamic> map = {};
    map["server_id"] = serverId;
    map["version"] = version;
    map["go"] = go;
    map["proto"] = proto;
    map["host"] = host;
    map["port"] = port;
    map["max_payload"] = maxPayload;
    map["client_id"] = clientId;
    map["version"] = version;
    map["auth_required"] = authRequired;
    map["tlsequired"] = tlsRequired;
    map["tls_verify"] = tlsVerify;
    map["connect_urls"] = serverUrls;
    
    return jsonEncode(map);
  }
}
