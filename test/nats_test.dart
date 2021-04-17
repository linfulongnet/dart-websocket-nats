import 'dart:async';

import "package:test/test.dart";
import "package:nats/nats.dart";

import '../lib/src/crypto.dart';
import '../lib/src/webSocketStatus.dart';

void main() async {
  group('[Test WebSocket NATS]:', () {
    test('Connect', () async {
      var client1 = NatsClient('ws://t2.bfdx.net:2235/nats');
      await client1.connect();

      client1.log.info("client1 connected: ${client1.serverinfo.toJson()}");
      expect(client1.status, WebSocketStatus.OPEN);

      await client1.close();
      expect(client1.status, WebSocketStatus.CLOSED);

      var client2 = NatsClient('ws://t2.bfdx.net:2235/nats');
      await client2.connect();
      client2.log.info("client2 connected: ${client2.serverinfo.toJson()}");
      expect(client2.status, WebSocketStatus.OPEN);

      await client2.close();
      expect(client2.status, WebSocketStatus.CLOSED);
    });

    test("Pub & Sub", () async {
      var client1 = NatsClient('ws://t2.bfdx.net:2235/nats');
      await client1.connect();
      var client2 = NatsClient('ws://t2.bfdx.net:2235/nats');
      await client2.connect();

      int maxTestCount = 10;
      int count = 1;
      int receivedCount = 0;
      Duration pubInterval = Duration(milliseconds: 500);

      client1.subscribe("sub-1").listen((msg) {
        receivedCount++;
        var _msg = decodeBase64Str(msg.payload!);
        client1.log.info("client1 Got message: $_msg, replyTo: ${msg.replyTo}");
        if (msg.replyTo != null)
          client1.publish(msg.replyTo!, encodeBase64Str("reply for: $_msg"));
      });

      client2.subscribe("sub-1-reply").listen((msg) {
        var _msg = decodeBase64Str(msg.payload!);
        client2.log.info(
            "client2 Got sub-1-reply message: $_msg, replyTo: ${msg.replyTo}");
      });

      while (count <= maxTestCount) {
        client2.publish("sub-1", encodeBase64Str("foo-${count++}"),
            replyTo: 'sub-1-reply');
        await Future.delayed(pubInterval);
      }

      expect(receivedCount, maxTestCount);
    });
  });
}
