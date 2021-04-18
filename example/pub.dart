import 'package:dart_websocket_nats/dart_websocket_nats.dart';

import '../lib/src/crypto.dart';

void main() async {
  var client = NatsClient('ws://localhost:9876/nats');
  await client.connect();

  client.log.info("[pub.dart] connected: ${client.serverinfo.toJson()}");

  client.subscribe("sub-1-reply", queueGroup: "foo.*").listen((msg) {
    client.log
        .info("Got sub-1-reply message: ${decodeBase64Str(msg.payload!)}");
  });

  client.publish("sub-1", encodeBase64Str("foo"), replyTo: 'sub-1-reply');
}
