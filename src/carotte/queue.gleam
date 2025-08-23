import carotte
import carotte/channel
import carotte/publisher
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process
import gleam/option.{None, Some}
import gleam/result

pub opaque type Queue {
  Queue(
    name: String,
    passive: Bool,
    durable: Bool,
    exclusive: Bool,
    auto_delete: Bool,
    nowait: Bool,
  )
}

pub type Deliver {
  Deliver(
    consumer_tag: String,
    delivery_tag: Int,
    redelivered: Bool,
    exchange: String,
    routing_key: String,
  )
}

pub type Payload {
  Payload(payload: String, properties: List(publisher.PublishOption))
}

pub type DeclaredQueue {
  DeclaredQueue(name: String, message_count: Int, consumer_count: Int)
}

/// Create a new queue with the given name
pub fn new(name: String) -> Queue {
  Queue(name, False, False, False, False, False)
}

/// If set, the queue must already exist on the broker
pub fn as_passive(queue: Queue) -> Queue {
  Queue(..queue, passive: True)
}

/// If set, the queue will survive a broker restart
pub fn as_durable(queue: Queue) -> Queue {
  Queue(..queue, durable: True)
}

/// If set, only one subscriber can consume from the Queue
pub fn as_exclusive(queue: Queue) -> Queue {
  Queue(..queue, exclusive: True)
}

/// If set, the queue will be deleted when the last subscriber disconnect
pub fn with_auto_delete(queue: Queue) -> Queue {
  Queue(..queue, auto_delete: True)
}

/// Declare a queue on the broker
pub fn declare(
  queue: Queue,
  channel: channel.Channel,
) -> Result(DeclaredQueue, carotte.CarotteError) {
  do_declare(
    channel,
    queue.name,
    queue.passive,
    queue.durable,
    queue.exclusive,
    queue.auto_delete,
    queue.nowait,
  )
}

@external(erlang, "carotte_ffi", "queue_declare")
fn do_declare(
  channel: channel.Channel,
  queue: String,
  passive: Bool,
  durable: Bool,
  exclusive: Bool,
  auto_delete: Bool,
  nowait: Bool,
) -> Result(DeclaredQueue, carotte.CarotteError)

/// Declare a queue on the broker asynchronously
pub fn declare_async(
  queue: Queue,
  channel: channel.Channel,
) -> Result(Nil, carotte.CarotteError) {
  do_declare_async(
    channel,
    queue.name,
    queue.passive,
    queue.durable,
    queue.exclusive,
    queue.auto_delete,
    True,
  )
}

@external(erlang, "carotte_ffi", "queue_declare")
fn do_declare_async(
  channel: channel.Channel,
  queue: String,
  passive: Bool,
  durable: Bool,
  exclusive: Bool,
  auto_delete: Bool,
  nowait: Bool,
) -> Result(Nil, carotte.CarotteError)

/// Delete a queue from the broker
/// If `if_unused` is set, the queue will only be deleted if it has no subscribers
/// If `if_empty` is set, the queue will only be deleted if it has no messages
pub fn delete(
  channel channel: channel.Channel,
  queue queue: String,
  if_unused if_unused: Bool,
  if_empty if_empty: Bool,
) -> Result(Int, carotte.CarotteError) {
  do_delete(channel, queue, if_unused, if_empty, False)
}

/// Delete a queue from the broker asynchronously. Same semantics as `delete`
pub fn delete_async(
  channel channel: channel.Channel,
  queue queue: String,
  if_unused if_unused: Bool,
  if_empty if_empty: Bool,
) -> Result(Nil, carotte.CarotteError) {
  use _ <- result.map(do_delete(channel, queue, if_unused, if_empty, True))
  Nil
}

@external(erlang, "carotte_ffi", "queue_delete")
fn do_delete(
  channel: channel.Channel,
  queue: String,
  if_unused: Bool,
  if_empty: Bool,
  nowait: Bool,
) -> Result(Int, carotte.CarotteError)

/// Bind a queue to an exchange
/// The `routing_key` is used to filter messages from the exchange
pub fn bind(
  channel channel: channel.Channel,
  queue queue: String,
  exchange exchange: String,
  routing_key routing_key: String,
) -> Result(Nil, carotte.CarotteError) {
  do_bind(channel, queue, exchange, routing_key, False)
}

/// Bind a queue to an exchange asynchronously. Same semantics as `bind`
pub fn bind_async(
  channel channel: channel.Channel,
  queue queue: String,
  exchange exchange: String,
  routing_key routing_key: String,
) -> Result(Nil, carotte.CarotteError) {
  do_bind(channel, queue, exchange, routing_key, True)
}

@external(erlang, "carotte_ffi", "queue_bind")
fn do_bind(
  channel: channel.Channel,
  queue: String,
  exchange: String,
  routing_key: String,
  nowait: Bool,
) -> Result(Nil, carotte.CarotteError)

/// Unbind a queue from an exchange
/// The `routing_key` is used to filter messages from the exchange
pub fn unbind(
  channel channel: channel.Channel,
  queue queue: String,
  exchange exchange: String,
  routing_key routing_key: String,
) -> Result(Nil, carotte.CarotteError) {
  do_unbind(channel, queue, exchange, routing_key)
}

@external(erlang, "carotte_ffi", "queue_unbind")
fn do_unbind(
  channel: channel.Channel,
  queue: String,
  exchange: String,
  routing_key: String,
) -> Result(Nil, carotte.CarotteError)

/// Purge a queue of all messages
pub fn purge(
  channel channel: channel.Channel,
  queue queue: String,
) -> Result(Int, carotte.CarotteError) {
  do_purge(channel, queue, False)
}

/// Purge a queue of all messages asynchronously
pub fn purge_async(
  channel channel: channel.Channel,
  queue queue: String,
) -> Result(Nil, carotte.CarotteError) {
  use _ <- result.map(do_purge(channel, queue, True))
  Nil
}

@external(erlang, "carotte_ffi", "queue_purge")
fn do_purge(
  channel: channel.Channel,
  queue: String,
  nowait: Bool,
) -> Result(Int, carotte.CarotteError)

/// Get the status of a queue
pub fn status(
  channel channel: channel.Channel,
  queue queue: String,
) -> Result(DeclaredQueue, carotte.CarotteError) {
  do_declare(channel, queue, True, False, False, False, False)
}

/// Subscribe to a queue
/// The `callback` function will be called with each message received, receiving the message Payload and a `Deliver` struct
pub fn subscribe(
  channel channel: channel.Channel,
  queue queue: String,
  callback fun: fn(Payload, Deliver) -> Nil,
) -> Result(String, carotte.CarotteError) {
  let consumer_pid = process.spawn(fn() { do_start_consumer(channel, fun) })
  consume(channel, queue, consumer_pid)
}

fn consume(
  channel channel: channel.Channel,
  queue queue: String,
  pid pid: process.Pid,
) -> Result(String, carotte.CarotteError) {
  do_consume_ffi(channel, queue, pid)
}

@external(erlang, "carotte_ffi", "consume")
fn do_consume_ffi(
  channel: channel.Channel,
  queue: String,
  pid: process.Pid,
) -> Result(String, carotte.CarotteError)

fn do_start_consumer(channel, fun) {
  let _consumer_tag =
    process.new_selector()
    |> process.select_record(atom.create("basic.consume_ok"), 2, fn(dyn) {
      let assert Ok(consumer_tag) = decode.run(dyn, decode.string)
      consumer_tag
    })
    |> process.selector_receive_forever()

  do_consume(channel, fun)
}

fn do_consume(channel, fun) {
  let #(basic_deliver, payload) =
    process.new_selector()
    |> process.select_record(atom.create("basic.cancel"), 2, fn(_consumer_tag) {
      process.send_exit(process.self())
      panic
    })
    |> process.select_record(
      atom.create("basic.cancel_ok"),
      2,
      fn(_consumer_tag) {
        process.send_exit(process.self())
        panic
      },
    )
    |> process.select_other(fn(a) {
      let basic_deliver_decoder = {
        use consumer_tag <- decode.subfield([1], decode.string)
        use delivery_tag <- decode.subfield([2], decode.int)
        use redelivered <- decode.subfield([3], decode.bool)
        use exchange <- decode.subfield([4], decode.string)
        use routing_key <- decode.subfield([5], decode.string)
        decode.success(Deliver(
          consumer_tag,
          delivery_tag,
          redelivered,
          exchange,
          routing_key,
        ))
      }
      let payload_properties_decoder = {
        let properties = []
        use content_type <- decode.subfield([1], decode.optional(decode.string))
        let properties =
          add_if_some(properties, publisher.ContentType, content_type)
        use content_encoding <- decode.subfield(
          [2],
          decode.optional(decode.string),
        )
        let properties =
          add_if_some(properties, publisher.ContentEncoding, content_encoding)
        use persistent <- decode.subfield([4], decode.optional(decode.int))
        let properties =
          add_if_some(properties, publisher.Persistent, case persistent {
            Some(1) -> Some(True)
            Some(2) -> Some(False)
            _ -> None
          })
        use priority <- decode.subfield([5], decode.optional(decode.int))
        let properties = add_if_some(properties, publisher.Priority, priority)
        use correlation_id <- decode.subfield(
          [6],
          decode.optional(decode.string),
        )
        let properties =
          add_if_some(properties, publisher.CorrelationId, correlation_id)
        use reply_to <- decode.subfield([7], decode.optional(decode.string))
        let properties = add_if_some(properties, publisher.ReplyTo, reply_to)
        use expiration <- decode.subfield([8], decode.optional(decode.string))
        let properties =
          add_if_some(properties, publisher.Expiration, expiration)
        use message_id <- decode.subfield([9], decode.optional(decode.string))
        let properties =
          add_if_some(properties, publisher.MessageId, message_id)
        use timestamp <- decode.subfield([10], decode.optional(decode.int))
        let properties = add_if_some(properties, publisher.Timestamp, timestamp)
        use message_type <- decode.subfield(
          [11],
          decode.optional(decode.string),
        )
        let properties = add_if_some(properties, publisher.Type, message_type)
        use user_id <- decode.subfield([12], decode.optional(decode.string))
        let properties = add_if_some(properties, publisher.UserId, user_id)
        use app_id <- decode.subfield([13], decode.optional(decode.string))
        let properties = add_if_some(properties, publisher.AppId, app_id)
        decode.success(properties)
      }
      let payload_decoder = {
        use properties <- decode.subfield([1], payload_properties_decoder)
        use payload <- decode.subfield([2], decode.string)
        decode.success(Payload(payload, properties))
      }
      let decoder = {
        use basic_deliver <- decode.subfield([0], basic_deliver_decoder)
        use payload <- decode.subfield([1], payload_decoder)
        decode.success(#(basic_deliver, payload))
      }
      let assert Ok(decoded) = decode.run(a, decoder)
      decoded
    })
    |> process.selector_receive_forever()
  fun(payload, basic_deliver)
  let _ = do_basic_ack(channel, basic_deliver.delivery_tag, False)
  do_consume(channel, fun)
}

@external(erlang, "carotte_ffi", "ack")
fn do_basic_ack(
  channel: channel.Channel,
  delivery_tag: Int,
  multiple: Bool,
) -> Result(Nil, carotte.CarotteError)

/// Acknowledge a message delivery.
/// Used when manual acknowledgment is enabled (NoAck(False)).
/// 
/// ## Parameters
/// - `channel`: The channel to acknowledge on
/// - `delivery_tag`: The delivery tag from the message metadata
/// - `multiple`: If True, acknowledges all messages up to and including this delivery tag
/// 
/// ## Example
/// ```gleam
/// queue.subscribe_with_options(
///   channel: ch,
///   queue: "my_queue",
///   options: [queue.NoAck(False)],
///   callback: fn(msg, meta) {
///     // Process message
///     let _ = queue.ack(ch, meta.delivery_tag, False)
///   },
/// )
/// ```
pub fn ack(
  channel: channel.Channel,
  delivery_tag: Int,
  multiple: Bool,
) -> Result(Nil, carotte.CarotteError) {
  do_basic_ack(channel, delivery_tag, multiple)
}

/// Acknowledge a message delivery (acknowledges only this message).
/// Convenience function for ack with multiple=False.
pub fn ack_single(
  channel: channel.Channel,
  delivery_tag: Int,
) -> Result(Nil, carotte.CarotteError) {
  do_basic_ack(channel, delivery_tag, False)
}

/// Unsubscribe a consumer from a queue
pub fn unsubscribe(
  channel channel: channel.Channel,
  consumer_tag consumer_tag: String,
) -> Result(Nil, carotte.CarotteError) {
  do_unsubscribe(channel, consumer_tag, False)
}

/// Unsubscribe a consumer from a queue asynchronously
pub fn unsubscribe_async(
  channel channel: channel.Channel,
  consumer_tag consumer_tag: String,
) -> Result(Nil, carotte.CarotteError) {
  do_unsubscribe(channel, consumer_tag, True)
}

@external(erlang, "carotte_ffi", "unsubscribe")
fn do_unsubscribe(
  channel: channel.Channel,
  consumer_tag: String,
  nowait: Bool,
) -> Result(Nil, carotte.CarotteError)

fn add_if_some(list, constructor, value) {
  case value {
    Some(v) -> [constructor(v), ..list]
    None -> list
  }
}
