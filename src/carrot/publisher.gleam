import carrot
import carrot/channel

pub type PublishOption {
  /// If set, returns an error if the broker can't route the message to a queue
  Mandatory(Bool)
  // Immediate(Bool) not supported
  /// MIME Content type
  ContentType(String)
  /// MIME Content encoding
  ContentEncoding(String)
  /// If set, uses persistent delivery mode. 
  /// Messages marked as persistent that are delivered to durable queues will be logged to disk
  Persistent(Bool)
  /// Arbitrary application-specific message identifier
  CorrelationId(String)
  /// Message priority, ranging from 0 to 9
  Priority(Int)
  /// Name of the reply queue
  ReplyTo(String)
  /// How long the message is valid (in milliseconds)
  Expiration(String)
  /// Message identifier
  MessageId(String)
  /// timestamp associated with this message (epoch time)
  Timestamp(Int)
  /// Message type
  Type(String)
  /// Creating user ID. RabbitMQ will validate this against the active connection user
  UserId(String)
  /// Application ID
  AppId(String)
}

/// Publish a message 'payload' to an exchange
/// The `routing_key` is used to filter messages from the exchange
/// The `options` are used to set message properties
pub fn publish(
  channel channel: channel.Channel,
  exchange exchange: String,
  routing_key routing_key: String,
  payload payload: String,
  options options: List(PublishOption),
) -> Result(Nil, carrot.CarrotError) {
  do_publish(channel, exchange, routing_key, payload, options)
}

@external(erlang, "carrot_ffi", "publish")
fn do_publish(
  channel: channel.Channel,
  exchange: String,
  routing_key: String,
  payload: String,
  publish_options: List(PublishOption),
) -> Result(Nil, carrot.CarrotError)
