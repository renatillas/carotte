import carotte
import carotte/channel
import carotte/exchange
import carotte/publisher
import carotte/queue
import gleam/erlang/process
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn declare_exchange_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  exchange.new("declare_exchange")
  |> exchange.with_type(exchange.Direct)
  |> exchange.as_durable()
  |> exchange.as_internal()
  |> exchange.with_auto_delete()
  |> exchange.declare(channel)
  |> should.be_ok()
}

pub fn delete_exchange_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  exchange.new("delete_exchange")
  |> exchange.with_type(exchange.Direct)
  |> exchange.as_durable()
  |> exchange.as_internal()
  |> exchange.with_auto_delete()
  |> exchange.declare(channel)
  |> should.be_ok()

  exchange.delete(channel, "delete_exchange", if_unused: False)
}

pub fn bind_exchanges_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  exchange.new("bind_exchange_source")
  |> exchange.with_type(exchange.Direct)
  |> exchange.declare(channel)
  |> should.be_ok()

  exchange.new("bind_exchange_destination")
  |> exchange.with_type(exchange.Direct)
  |> exchange.declare(channel)
  |> should.be_ok()

  exchange.bind(
    channel: channel,
    source: "bind_exchange_source",
    destination: "bind_exchange_destination",
    routing_key: "test",
  )
  |> should.be_ok()
  exchange.bind(
    channel: channel,
    source: "bind_exchange_source",
    destination: "bind_exchange_destination",
    routing_key: "another",
  )
  |> should.be_ok()
}

pub fn unbind_exchanges_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  exchange.new("unbind_exchange_source")
  |> exchange.with_type(exchange.Direct)
  |> exchange.declare(channel)
  |> should.be_ok()

  exchange.new("unbind_exchange_destination")
  |> exchange.with_type(exchange.Direct)
  |> exchange.declare(channel)
  |> should.be_ok()

  exchange.bind(
    channel: channel,
    source: "unbind_exchange_source",
    destination: "unbind_exchange_destination",
    routing_key: "test",
  )
  |> should.be_ok()

  exchange.unbind(
    channel: channel,
    source: "unbind_exchange_source",
    destination: "unbind_exchange_destination",
    routing_key: "test",
  )
  |> should.be_ok()
}

pub fn declare_queue_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  queue.new("declare_queue")
  |> queue.declare(channel)
  |> should.be_ok()
  |> should.equal(queue.DeclaredQueue("declare_queue", 0, 0))
}

pub fn declare_queue_async_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  queue.new("declare_queue_async")
  |> queue.declare_async(channel)
  |> should.be_ok()
  |> should.equal(Nil)
}

pub fn delete_queue_async_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  queue.new("delete_queue")
  |> queue.declare(channel)
  |> should.be_ok()

  queue.delete(channel, "delete_queue", False, False)
  |> should.be_ok()
  |> should.equal(0)
}

pub fn bind_queue_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  queue.new("bind_queue")
  |> queue.declare(channel)
  |> should.be_ok()

  exchange.new("bind_queue_exchange")
  |> exchange.declare(channel)
  |> should.be_ok()

  queue.bind(
    channel: channel,
    queue: "bind_queue",
    exchange: "bind_queue_exchange",
    routing_key: "test",
  )
  |> should.be_ok()
}

pub fn unbind_queue_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  queue.new("unbind_queue")
  |> queue.declare(channel)
  |> should.be_ok()

  exchange.new("unbind_queue_exchange")
  |> exchange.declare(channel)
  |> should.be_ok()

  queue.bind(
    channel: channel,
    queue: "unbind_queue",
    exchange: "unbind_queue_exchange",
    routing_key: "test",
  )
  |> should.be_ok()

  queue.unbind(
    channel: channel,
    queue: "unbind_queue",
    exchange: "unbind_queue_exchange",
    routing_key: "test",
  )
  |> should.be_ok()
}

pub fn purge_queue_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  queue.new("purge_queue")
  |> queue.declare(channel)
  |> should.be_ok()

  queue.purge(channel, "purge_queue")
  |> should.be_ok()
  |> should.equal(0)
}

pub fn purge_queue_async_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  queue.new("purge_queue_async")
  |> queue.declare(channel)
  |> should.be_ok()

  queue.purge_async(channel, "purge_queue_async")
  |> should.be_ok()
  |> should.equal(Nil)
}

pub fn queue_status_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  queue.new("queue_status")
  |> queue.declare(channel)
  |> should.be_ok()

  queue.status(channel, "queue_status")
  |> should.be_ok()
  |> should.equal(queue.DeclaredQueue("queue_status", 0, 0))
}

pub fn publish_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  exchange.new("p_exchange")
  |> exchange.declare(channel)
  |> should.be_ok()

  queue.new("p_queue")
  |> queue.declare(channel)
  |> should.be_ok()

  publisher.publish(
    channel: channel,
    exchange: "p_exchange",
    routing_key: "",
    payload: "test",
    options: [],
  )
  |> should.be_ok()
}

pub fn publish_with_options_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  exchange.new("pwo_exchange")
  |> exchange.declare(channel)
  |> should.be_ok()

  queue.new("pwo_queue")
  |> queue.declare(channel)
  |> should.be_ok()

  let headers =
    publisher.headers_from_list([
      #("string_key", publisher.StringHeader("value")),
      #("bool_key", publisher.BoolHeader(True)),
      #(
        "list_key",
        publisher.ListHeader([
          publisher.StringHeader("value1"),
          publisher.StringHeader("value2"),
        ]),
      ),
    ])

  publisher.publish(
    channel: channel,
    exchange: "pwo_exchange",
    routing_key: "",
    payload: "test",
    options: [
      publisher.Mandatory(True),
      publisher.ContentType("text/plain"),
      publisher.ContentEncoding("utf-8"),
      publisher.Headers(headers),
      publisher.Persistent(True),
      publisher.CorrelationId("123"),
      publisher.Priority(9),
      publisher.Expiration("1000"),
      publisher.MessageId("123"),
      publisher.Timestamp(123),
      publisher.Type("test"),
    ],
  )
  |> should.be_ok()
}

pub fn subscribe_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  exchange.new("consume_exchange")
  |> exchange.declare(channel)
  |> should.be_ok()
  queue.new("consume_queue")
  |> queue.declare(channel)
  |> should.be_ok()

  queue.bind(
    channel: channel,
    queue: "consume_queue",
    exchange: "consume_exchange",
    routing_key: "",
  )
  |> should.be_ok()

  publisher.publish(
    channel: channel,
    exchange: "consume_exchange",
    routing_key: "",
    payload: "payload",
    options: [],
  )
  |> should.be_ok()

  queue.subscribe(
    channel: channel,
    queue: "consume_queue",
    callback: fn(payload, _) {
      payload.payload
      |> should.equal("payload")
    },
  )
  |> should.be_ok()
  process.sleep(1000)
}

pub fn unsubscribe_test() {
  let client =
    carotte.default_client()
    |> carotte.start()
    |> should.be_ok()

  let channel =
    channel.open_channel(client)
    |> should.be_ok()

  exchange.new("unsubscribe_exchange")
  |> exchange.declare(channel)
  |> should.be_ok()
  queue.new("unsubscribe_queue")
  |> queue.declare(channel)
  |> should.be_ok()

  queue.bind(
    channel: channel,
    queue: "unsubscribe_queue",
    exchange: "unsubscribe_exchange",
    routing_key: "",
  )
  |> should.be_ok()

  publisher.publish(
    channel: channel,
    exchange: "unsubscribe_exchange",
    routing_key: "",
    payload: "payload",
    options: [
      publisher.Mandatory(True),
      publisher.ContentType("text/plain"),
      publisher.ContentEncoding("utf-8"),
      publisher.Persistent(True),
      publisher.CorrelationId("123"),
      publisher.Priority(9),
      publisher.Expiration("1000"),
      publisher.MessageId("123"),
      publisher.Timestamp(123),
      publisher.Type("test"),
    ],
  )
  |> should.be_ok()

  let consumer_tag =
    queue.subscribe(
      channel: channel,
      queue: "unsubscribe_queue",
      callback: fn(payload, _) {
        payload.payload
        |> should.equal("payload")
      },
    )
    |> should.be_ok()

  queue.unsubscribe(channel, consumer_tag)
  |> should.be_ok()
  process.sleep(1000)
}

pub fn auth_failure_test() {
  let assert Error(carotte.AuthFailure(_)) =
    carotte.default_client()
    |> carotte.with_password("wrong")
    |> carotte.start()
}
