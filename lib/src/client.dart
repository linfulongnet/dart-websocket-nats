import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as SocketChannelStatus;
import 'package:logging/logging.dart';

import 'config.dart';
import 'serverInfo.dart';
import 'message.dart';
import 'connectionOptions.dart';
import 'subscription.dart';
import 'webSocketStatus.dart';

bool _isInitLogger = false;
typedef IDBuilder = int Function();
IDBuilder _idBuilder({int maxId = 2 << 32, int start = 0}) {
  int _sid = start;
  return () {
    if (_sid >= maxId) {
      _sid = 0;
    }

    return _sid++;
  };
}

IDBuilder _cliUid = _idBuilder();

class NatsClient {
  late String _name;
  String get name => _name;

  late ServerInfo _serverInfo;
  ServerInfo get serverinfo => _serverInfo;

  late StreamController<Message> _messagesController;
  late List<Subscription> _subscriptions;
  late String _url;
  late IOWebSocketChannel _channel;
  late Completer _connectCompleter;
  late Logger log;

  // ignore: unused_field
  Iterable<String>? _protocols;
  // ignore: unused_field
  Map<String, dynamic>? _headers;
  // ignore: unused_field
  Duration? _pingInterval;
  ConnectionOptions _connectionOptions = ConnectionOptions(
    verbose: false,
    pedantic: true,
    tlsRequired: false,
    language: 'dart',
  );

  IDBuilder _nextSid = _idBuilder();
  int get sid => _nextSid();

  int _socketStatus = WebSocketStatus.CLOSED;
  int get status => _socketStatus;

  // 记录ping失败次数，达到最大次数(Config.DEFAULT_MAX_PING_OUT)则断开连接，重新连接websocket
  int _pingOutCount = 0;
  late Completer _pingCompleter;
  DateTime _lastReceivedTime = DateTime.now();

  NatsClient(String url, {Level logLevel = Level.SEVERE}) {
    _url = url;
    _serverInfo = ServerInfo();
    _subscriptions = <Subscription>[];
    _messagesController = new StreamController.broadcast();
    _name = 'NATS_CLIENT_' + _cliUid().toString();

    _initLogger(logLevel);
  }

  void _initLogger(Level logLevel) {
    log = Logger(_name);
    if (_isInitLogger) return;

    _isInitLogger = true;
    Logger.root.level = logLevel;
    Logger.root.onRecord.listen((record) {
      print(
          '[${log.fullName} ${record.level.name} ${record.time}]: ${record.message}');
    });
  }

  Future<void> connect(
      {Iterable<String>? protocols,
      Map<String, dynamic>? headers,
      Duration? pingInterval,
      ConnectionOptions? connectionOptions}) {
    log.config('NATS server connecting...');
    _connectCompleter = Completer();
    _socketStatus = WebSocketStatus.CONNECTING;

    if (protocols != null) _protocols = protocols;
    if (headers != null) _headers = headers;
    if (pingInterval != null) _pingInterval = pingInterval;
    if (connectionOptions != null) _connectionOptions = connectionOptions;

    _channel = IOWebSocketChannel.connect(_url,
        protocols: protocols, headers: headers, pingInterval: pingInterval);
    _socketStatus = WebSocketStatus.OPEN;

    _channel.stream.listen((message) {
      log.finest('_channel received message: $message');
      // 记录接收到数据的时间
      _lastReceivedTime = DateTime.now();
      _loopProcess(message);
    });

    return _connectCompleter.future;
  }

  _loopProcess(String message) {
    if (message.startsWith(Config.MSG)) {
      _convertToMessages(message)
          .forEach((msg) => _messagesController.add(msg));
    } else if (message.startsWith(Config.PING)) {
      _sendPong();
    } else if (message.startsWith(Config.PONG)) {
      _receivedPong();
    } else if (message.startsWith(Config.OK)) {
      log.info("Received server OK");
    } else if (message.startsWith(Config.ERR)) {
      _receivedErrorMessage();
    } else if (message.startsWith(Config.INFO)) {
      _serverInfo.fromJson(message.replaceFirst(Config.INFO, ""));
      _sendConnection(_connectionOptions);
      _connectCompleter.complete();
      _initHeartbeat();
    } else {
      log.warning('Unknow message => $message');
    }
  }

  void _resetBeforeConnectProps() {
    _pingOutCount = 0;
  }

  _reconnect() async {
    log.warning('NATS server reconect');
    // 重置连接前的一些参数
    _resetBeforeConnectProps();
    await Future.delayed(Duration(seconds: Config.DEFAULT_RECONNECT_TIME_WAIT));
    await connect();
    // 将上个socket连接的订阅事件，重新订阅
    _carryOverSubscriptions();
  }

  _receivedErrorMessage() async {
    _socketStatus = WebSocketStatus.CLOSING;
    await _channel.sink.close(SocketChannelStatus.unsupportedData);
    _socketStatus = WebSocketStatus.CLOSED;
    _reconnect();
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
    log.finest('_carryOverSubscriptions: $_subscriptions');
    _subscriptions.forEach((sub) {
      _doSubscribe(sub);
    });
  }

  void _add(String msg) {
    // ignore: unnecessary_null_comparison
    if (_socketStatus != WebSocketStatus.OPEN || _channel.sink == null) {
      _socketStatus = WebSocketStatus.CLOSED;
      log.severe(
          "Socket not ready. Please check if NatsClient.connect() is called");
      return;
    }

    log.info('_channel.sink.add: $msg');
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

  // ignore: unused_element
  void _sendPong() {
    _add("${Config.PONG}${Config.CR_LF}");
  }

  void _sendPing() {
    _pingCompleter = Completer();
    _add("${Config.PING}${Config.CR_LF}");
  }

  Future _checkPing(
      {int awaitPingInterval = Config.DEFAULT_PING_INTERVAL}) async {
    // 在下轮发送ping命令前，先检测是否达到失联最大次数，如果是，则断开websocket并重连
    await Future.delayed(Duration(milliseconds: awaitPingInterval));
    log.finest('_checkPing: _lastReceivedTime=$_lastReceivedTime');

    if (_pingOutCount >= Config.DEFAULT_MAX_PING_OUT) {
      log.severe('_checkPing: ${Config.MAX_PING_TIMEOUT_LIMIT}');
      await close(
          closeCode: SocketChannelStatus.noStatusReceived,
          closeReason: Config.MAX_PING_TIMEOUT_LIMIT);
      _reconnect();
      return;
    }

    // 如果上次收到NATS服务器的消息，则说明socket连接一直存活
    DateTime _now = DateTime.now();
    DateTime _t =
        _now.subtract(Duration(milliseconds: Config.DEFAULT_PING_INTERVAL));
    var nextPingTime = Config.DEFAULT_PING_INTERVAL;
    // 在ping周期内有数据
    if (_lastReceivedTime.isAfter(_t)) {
      if (_pingCompleter.isCompleted) {
        _pingOutCount = 0;
      } else {
        _receivedPong();
      }
      // 重新计算下轮ping命令的间隔时间
      nextPingTime = _lastReceivedTime
              .add(Duration(milliseconds: Config.DEFAULT_PING_INTERVAL))
              .millisecondsSinceEpoch -
          _now.millisecondsSinceEpoch;
    } else {
      // 没有收到NATS服务器的消息，则计算ping失联次数
      _pingOutCount++;
    }

    await Future.delayed(Duration(milliseconds: nextPingTime));

    _sendPing();
    _checkPing();
  }

  void _initHeartbeat() {
    log.finest('_initHeartbeat');
    // first ping
    _sendPing();
    // auto ping
    _checkPing();
  }

  void _receivedPong() {
    if (!_pingCompleter.isCompleted) {
      _pingCompleter.complete();
    }
    // 需要重置ping失败的计数器
    _pingOutCount = 0;
  }

  void _sendConnection(ConnectionOptions opts) {
    var connectStr = '${Config.CONNECT}${opts.toJson()}${Config.CR_LF}';
    _add(connectStr);
  }

  Future close({int? closeCode, String? closeReason}) {
    log.finest(
        'NATS server close: closeCode=$closeCode, closeReason=$closeReason');
    _socketStatus = WebSocketStatus.CLOSED;
    return _channel.sink.close(closeCode, closeReason);
  }
}
