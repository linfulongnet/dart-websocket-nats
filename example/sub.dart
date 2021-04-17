import 'package:nats/nats.dart';

import '../lib/src/crypto.dart';

void main() async {
  var client = NatsClient('ws://localhost:9876/nats');
  await client.connect();

  client.log.info("[sub.dart] connected: ${client.serverinfo.toJson()}");

  client.subscribe("sub-1", queueGroup: "foo.*").listen((msg) {
    client.log.info("Got message: ${decodeBase64Str(msg.payload!)}");
    if (msg.replyTo != null)
      client.publish(
          msg.replyTo!, encodeBase64Str("reply for: ${msg.subject}"));
  });
}
