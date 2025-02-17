import carrot
import carrot/channel

pub opaque type Exchange {
  Exchange(
    name: String,
    exchange_type: ExchangeType,
    durable: Bool,
    auto_delete: Bool,
    internal: Bool,
    nowait: Bool,
  )
}

pub type ExchangeType {
  Fanout
  Direct
  Topic
  Headers
}

/// Create a new exchange with the given name
/// Defaults to a direct exchange
pub fn new(name: String) -> Exchange {
  Exchange(name, Direct, False, False, False, False)
}

/// Give the exchange a type: fanout, direct, topic, or headers
pub fn with_type(exchange: Exchange, exchange_type: ExchangeType) -> Exchange {
  Exchange(..exchange, exchange_type:)
}

/// If set, the exchange may not be used directly by publishers, but only when bound to other exchanges.
/// Internal exchanges are used to construct wiring that is not visible to applications
pub fn as_internal(exchange: Exchange) -> Exchange {
  Exchange(..exchange, internal: True)
}

/// If set, the exchange will be deleted when the last queue is unbound from it
pub fn with_auto_delete(exchange: Exchange) -> Exchange {
  Exchange(..exchange, auto_delete: True)
}

/// If set, the exchange will survive a broker restart
pub fn as_durable(exchange: Exchange) -> Exchange {
  Exchange(..exchange, durable: True)
}

/// Declare an exchange on the broker
pub fn declare(
  exchange: Exchange,
  channel: channel.Channel,
) -> Result(Nil, carrot.CarrotError) {
  do_declare(channel, exchange)
}

/// Declare an exchange on the broker without waiting for a response
pub fn declare_async(
  exchange: Exchange,
  channel: channel.Channel,
) -> Result(Nil, carrot.CarrotError) {
  do_declare(channel, Exchange(..exchange, nowait: True))
}

@external(erlang, "carrot_ffi", "exchange_declare")
fn do_declare(
  channel: channel.Channel,
  exchange: Exchange,
) -> Result(Nil, carrot.CarrotError)

/// Delete an exchange from the broker
/// If `unused` is set to true, the exchange will only be deleted if it has no queues bound to it
pub fn delete(
  channel channel: channel.Channel,
  exchange exchange: String,
  if_unused unused: Bool,
) -> Result(Nil, carrot.CarrotError) {
  do_delete(channel, exchange, unused, False)
}

/// Delete an exchange from the broker without waiting for a response
pub fn delete_async(
  channel channel: channel.Channel,
  exchange exchange: String,
  unused unused: Bool,
) -> Result(Nil, carrot.CarrotError) {
  do_delete(channel, exchange, unused, True)
}

@external(erlang, "carrot_ffi", "exchange_delete")
fn do_delete(
  channel: channel.Channel,
  exchange: String,
  if_unused: Bool,
  nowait: Bool,
) -> Result(Nil, carrot.CarrotError)

/// Bind an exchange to another exchange
/// Routing keys are used to filter messages from the source exchange
pub fn bind(
  channel channel: channel.Channel,
  source source: String,
  destination destination: String,
  routing_key routing_key: String,
) -> Result(Nil, carrot.CarrotError) {
  do_bind(channel, source, destination, routing_key, False)
}

pub fn bind_async(
  channel channel: channel.Channel,
  source source: String,
  destination destination: String,
  routing_key routing_key: String,
) -> Result(Nil, carrot.CarrotError) {
  do_bind(channel, source, destination, routing_key, True)
}

@external(erlang, "carrot_ffi", "exchange_bind")
fn do_bind(
  channel: channel.Channel,
  source: String,
  destination: String,
  routing_key: String,
  nowait: Bool,
) -> Result(Nil, carrot.CarrotError)

/// Unbind an exchange from another exchange
pub fn unbind(
  channel channel: channel.Channel,
  source source: String,
  destination destination: String,
  routing_key routing_key: String,
) -> Result(Nil, carrot.CarrotError) {
  do_unbind(channel, source, destination, routing_key, False)
}

/// Unbind an exchange from another exchange asynchronously. Same semantics as `unbind`
pub fn unbind_async(
  channel channel: channel.Channel,
  source source: String,
  destination destination: String,
  routing_key routing_key: String,
) -> Result(Nil, carrot.CarrotError) {
  do_unbind(channel, source, destination, routing_key, True)
}

@external(erlang, "carrot_ffi", "exchange_unbind")
fn do_unbind(
  channel: channel.Channel,
  source: String,
  destination: String,
  routing_key: String,
  nowait: Bool,
) -> Result(Nil, carrot.CarrotError)
