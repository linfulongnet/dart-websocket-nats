import 'dart:convert';

import 'config.dart';
import 'serverInfo.dart';
import 'message.dart';
import 'connectionOptions.dart';
import 'subscription.dart';

import 'dart:async';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as WebsocketStatus;
import 'package:logger/logger.dart';

int _sid = 0;
const int maxSid = 2 << 32;
int nextSid() {
  if (_sid >= maxSid) {
    _sid = 0;
  }

  return _sid++;
}

class NatsClient {
  final Logger log = Logger(
      printer: PrettyPrinter(
          methodCount: 2, // number of method calls to be displayed
          errorMethodCount:
              8, // number of method calls if stacktrace is provided
          lineLength: 120, // width of the output
          colors: true, // Colorful log messages
          printEmojis: true, // Print an emoji for each log message
          printTime: true // Should each log print contain a timestamp
          ));
  late ServerInfo _serverInfo;
  ServerInfo get serverinfo => _serverInfo;
  late StreamController<Message> _messagesController;
  late List<Subscription> _subscriptions;
  late String _url;
  late IOWebSocketChannel _channel;
  late Completer _connectCompleter;
  Iterable<String>? _protocols;
  Map<String, dynamic>? _headers;
  Duration? _pingInterval;
  ConnectionOptions _connectionOptions = ConnectionOptions(
    verbose: false,
    pedantic: true,
    tlsRequired: false,
    language: 'dart',
  );
  int get sid => nextSid();

  NatsClient(String url, {Level logLevel = Level.info}) {
    _url = url;
    _serverInfo = ServerInfo();
    _subscriptions = <Subscription>[];
    _messagesController = new StreamController.broadcast();
    Logger.level = logLevel;
  }

  Future<void> connect(
      {Iterable<String>? protocols,
      Map<String, dynamic>? headers,
      Duration? pingInterval,
      ConnectionOptions? connectionOptions}) {
    _connectCompleter = Completer();

    if (protocols != null) _protocols = protocols;
    if (headers != null) _headers = headers;
    if (pingInterval != null) _pingInterval = pingInterval;
    if (connectionOptions != null) _connectionOptions = connectionOptions;

    _channel = IOWebSocketChannel.connect(_url,
        protocols: protocols, headers: headers, pingInterval: pingInterval);

    _channel.stream.listen((message) {
      _loopProcess(message);
    });

    return _connectCompleter.future;
  }

  _loopProcess(String message) {
    if (message.startsWith(Config.MSG)) {
      log.i('_loopProcess message: $message');
      _convertToMessages(message)
          .forEach((msg) => _messagesController.add(msg));
    } else if (message.startsWith(Config.OK)) {
      log.i("Received server OK");
    } else if (message.startsWith(Config.PING)) {
      _sendPing();
    } else if (message.startsWith(Config.PONG)) {
      Future.delayed(Duration(seconds: Config.DEFAULT_PING_INTERVAL), () {
        _sendPing();
      });
    } else if (message.startsWith(Config.ERR)) {
      _channel.sink.close(WebsocketStatus.unsupportedData);
      _reconnect();
    } else if (message.startsWith(Config.INFO)) {
      _serverInfo.fromJson(message.replaceFirst(Config.INFO, ""));
      _sendConnection(_connectionOptions);
      _connectCompleter.complete();
    } else {
      log.w('Unknow message => $message');
    }
  }

  _reconnect() async {
    await Future.delayed(Duration(seconds: Config.DEFAULT_RECONNECT_TIME_WAIT));
    await connect();
    // 将上个socket连接的订阅事件，重新订阅
    _carryOverSubscriptions();
  }

  Message _convertToMessage(String message) {
    var natsMsg = Message();
    List<String> lines = message.split(Config.CR_LF);
    List<String> firstLineParts = lines[0].split(" ");
    natsMsg.subject = firstLineParts[0];
    natsMsg.sid = int.parse(firstLineParts[1]);
    bool replySubjectPresent = firstLineParts.length == 4;
    if (replySubjectPresent) {
      natsMsg.replyTo = firstLineParts[2];
      natsMsg.length = int.parse(firstLineParts[3]);
    } else {
      natsMsg.length = int.parse(firstLineParts[2]);
    }
    natsMsg.payload = lines[1];
    return natsMsg;
  }

  List<Message> _convertToMessages(String message) => message
      .split(Config.MSG)
      .where((msg) => msg.length > 0)
      .map((msg) => _convertToMessage(msg))
      .toList();

  /// Carries over [Subscription] objects from one host to another during cluster rearrangement
  void _carryOverSubscriptions() {
    _subscriptions.forEach((sub) {
      _doSubscribe(sub);
    });
  }

  void _add(String msg) {
    if (_channel.sink == null) {
      log.e("Socket not ready. Please check if NatsClient.connect() is called");
      return;
    }

    log.i('_channel.sink.add: $msg');
    _channel.sink.add(utf8.encode(msg));
  }

  void _publish(String subject, String message, {String? replyTo}) {
    var length = message.length;
    var msg = Config.EMPTY;
    if (replyTo == null) {
      msg =
          '${Config.PUB}$subject ${length}${Config.CR_LF}$message${Config.CR_LF}';
    } else {
      msg =
          '${Config.PUB}$subject $replyTo ${length}${Config.CR_LF}$message${Config.CR_LF}';
    }

    _add(msg);
  }

  /// Publishes the [message] to the [subject] with an optional [replyTo] set to receive the response
  void publish(String subject, String message, {String? replyTo}) {
    _publish(subject, message, replyTo: replyTo);
  }

  /// Subscribes to the [subject] with a given [subscriberId] and an optional [queueGroup] set to group the responses
  Stream<Message> subscribe(String subject, {String? queueGroup}) {
    var sub = Subscription(sid, subject, queueGroup: queueGroup);
    _subscriptions.add(sub);

    return _doSubscribe(sub);
  }

  void _subscribe(Subscription sub) {
    var msg = Config.EMPTY;
    if (sub.queueGroup == null) {
      msg = '${Config.SUB}${sub.subject} ${sub.sid}${Config.CR_LF}';
    } else {
      msg =
          '${Config.SUB}${sub.subject} ${sub.queueGroup} ${sub.sid}${Config.CR_LF}';
    }

    _add(msg);
  }

  Stream<Message> _doSubscribe(Subscription sub) {
    _subscribe(sub);
    return _messagesController.stream.where((incomingMsg) {
      log.i('incomingMsg: $incomingMsg');
      return _matchesRegex(sub.subject, incomingMsg.subject!);
    });
  }

  bool _matchesRegex(String listeningSubject, String incomingSubject) {
    var expression = RegExp("$listeningSubject");
    return expression.hasMatch(incomingSubject);
  }

  void _unsubscribe(int sid, {int? waitUntilMessageCount}) {
    var msg = Config.EMPTY;
    if (waitUntilMessageCount == null) {
      msg = '${Config.UNSUB}${sid}${Config.CR_LF}';
    } else {
      msg = '${Config.UNSUB}${sid} $waitUntilMessageCount${Config.CR_LF}';
    }

    _add(msg);
  }

  void unsubscribe(String subject, {int waitUntilMessageCount = 1}) {
    Iterable<Subscription> subs =
        _subscriptions.where((sub) => sub.subject == subject);
    subs.forEach((sub) {
      _unsubscribe(sub.sid, waitUntilMessageCount: waitUntilMessageCount);
      _subscriptions.remove(sub);
    });
  }

  void _sendPong() {
    _add("${Config.PONG}${Config.CR_LF}");
  }

  void _sendPing() {
    _add("${Config.PING}${Config.CR_LF}");
  }

  void _sendConnection(ConnectionOptions opts) {
    var connectStr = '${Config.CONNECT}${opts.toJson()}${Config.CR_LF}';
    _add(connectStr);
    _sendPing();
  }
}
