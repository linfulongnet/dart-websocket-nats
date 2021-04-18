class Config {
  // NATS commands
  static const MSG = "MSG ";
  static const PUB = "PUB ";
  static const SUB = "SUB ";
  static const UNSUB = "UNSUB ";
  static const INFO = "INFO ";
  static const PING = "PING";
  static const PONG = "PONG";
  static const CONNECT = "CONNECT ";
  static const OK = "+OK";
  static const ERR = "-ERR";

  // NATS PUB/SUB/UNSUB commonands structure helper
  static const CR_LF = '\r\n';
  static const CR_LF_LEN = CR_LF.length;
  static const EMPTY = '';

  // Reconnect Parameters, 5 sec wait, 30 tries
  static const DEFAULT_RECONNECT_TIME_WAIT = 5 * 1000;
  static const DEFAULT_MAX_RECONNECT_ATTEMPTS = 30;

  // Ping interval
  static const DEFAULT_PING_INTERVAL = 3 * 60 * 1000; // 3 minutes
  static const DEFAULT_MAX_PING_OUT = 3;

  // Errors
  static const BAD_SUBJECT = 'Subject must be supplied';
  static const BAD_MSG = 'Message can\'t be a function';
  static const BAD_REPLY = 'Reply can\'t be a function';
  static const CONN_CLOSED = 'Connection closed';
  static const BAD_JSON_MSG = 'Message should be a JSON object';
  static const BAD_AUTHENTICATION = 'User and Token can not both be provided';
  static const MAX_PING_TIMEOUT_LIMIT =
      'The number of PING failures reaches the upper limit';
}
