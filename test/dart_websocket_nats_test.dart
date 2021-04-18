import 'dart:async';

import 'package:logging/logging.dart';
import "package:test/test.dart";
import 'package:dart_websocket_nats/dart_websocket_nats.dart';

import '../lib/src/crypto.dart';
import '../lib/src/webSocketStatus.dart';

void main() async {
  String _url = 'ws://t2.bfdx.net:2235/nats';

  group('[Test WebSocket NATS]:', () {
    test('Connect', () async {
      var client = NatsClient(_url, logLevel: Level.INFO);
      await client.connect();

      client.log.info("client connected: ${client.serverinfo.toJson()}");
      expect(client.status, WebSocketStatus.OPEN);

      await client.close();
      expect(client.status, WebSocketStatus.CLOSED);
    });

    test("Pub & Sub", () async {
      var client1 = NatsClient(_url);
      await client1.connect();
      var client2 = NatsClient(_url);
      await client2.connect();

      int maxTestCount = 10;
      int count = 1;
      int receivedCount = 0;

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
        await Future.delayed(Duration(milliseconds: 300));
      }

      expect(receivedCount, maxTestCount);
      await Future.delayed(Duration(seconds: 2));
    });
  });
}
