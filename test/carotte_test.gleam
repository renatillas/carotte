import carotte
import carotte/channel
import carotte/exchange
import carotte/publisher
import carotte/queue
import gleam/erlang/process
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn declare_exchange_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) =
    exchange.new("declare_exchange")
    |> exchange.with_type(exchange.Direct)
    |> exchange.as_durable()
    |> exchange.as_internal()
    |> exchange.with_auto_delete()
    |> exchange.declare(channel)
}

pub fn delete_exchange_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) =
    exchange.new("delete_exchange")
    |> exchange.with_type(exchange.Direct)
    |> exchange.as_durable()
    |> exchange.as_internal()
    |> exchange.with_auto_delete()
    |> exchange.declare(channel)

  exchange.delete(channel, "delete_exchange", if_unused: False)
}

pub fn bind_exchanges_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) =
    exchange.new("bind_exchange_source")
    |> exchange.with_type(exchange.Direct)
    |> exchange.declare(channel)

  let assert Ok(_) =
    exchange.new("bind_exchange_destination")
    |> exchange.with_type(exchange.Direct)
    |> exchange.declare(channel)

  let assert Ok(_) =
    exchange.bind(
      channel: channel,
      source: "bind_exchange_source",
      destination: "bind_exchange_destination",
      routing_key: "test",
    )
  let assert Ok(_) =
    exchange.bind(
      channel: channel,
      source: "bind_exchange_source",
      destination: "bind_exchange_destination",
      routing_key: "another",
    )
}

pub fn unbind_exchanges_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) =
    exchange.new("unbind_exchange_source")
    |> exchange.with_type(exchange.Direct)
    |> exchange.declare(channel)

  let assert Ok(_) =
    exchange.new("unbind_exchange_destination")
    |> exchange.with_type(exchange.Direct)
    |> exchange.declare(channel)

  let assert Ok(_) =
    exchange.bind(
      channel: channel,
      source: "unbind_exchange_source",
      destination: "unbind_exchange_destination",
      routing_key: "test",
    )

  let assert Ok(_) =
    exchange.unbind(
      channel: channel,
      source: "unbind_exchange_source",
      destination: "unbind_exchange_destination",
      routing_key: "test",
    )
}

pub fn declare_queue_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(value) = queue.declare(queue.new("declare_queue"), channel)
  assert value == queue.DeclaredQueue("declare_queue", 0, 0)
}

pub fn declare_queue_async_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(value) =
    queue.declare_async(queue.new("declare_queue_async"), channel)
  assert value == Nil
}

pub fn delete_queue_async_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) = queue.declare(queue.new("delete_queue"), channel)

  let assert Ok(value) = queue.delete(channel, "delete_queue", False, False)
  assert value == 0
}

pub fn bind_queue_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) = queue.declare(queue.new("bind_queue"), channel)

  let assert Ok(_) =
    exchange.declare(exchange.new("bind_queue_exchange"), channel)

  let assert Ok(_) =
    queue.bind(
      channel: channel,
      queue: "bind_queue",
      exchange: "bind_queue_exchange",
      routing_key: "test",
    )
}

pub fn unbind_queue_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) = queue.declare(queue.new("unbind_queue"), channel)

  let assert Ok(_) =
    exchange.declare(exchange.new("unbind_queue_exchange"), channel)

  let assert Ok(_) =
    queue.bind(
      channel: channel,
      queue: "unbind_queue",
      exchange: "unbind_queue_exchange",
      routing_key: "test",
    )

  let assert Ok(_) =
    queue.unbind(
      channel: channel,
      queue: "unbind_queue",
      exchange: "unbind_queue_exchange",
      routing_key: "test",
    )
}

pub fn purge_queue_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) = queue.declare(queue.new("purge_queue"), channel)

  let assert Ok(value) = queue.purge(channel, "purge_queue")
  assert value == 0
}

pub fn purge_queue_async_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) = queue.declare(queue.new("purge_queue_async"), channel)

  let assert Ok(value) = queue.purge_async(channel, "purge_queue_async")
  assert value == Nil
}

pub fn queue_status_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) = queue.declare(queue.new("queue_status"), channel)

  let assert Ok(value) = queue.status(channel, "queue_status")
  assert value == queue.DeclaredQueue("queue_status", 0, 0)
}

pub fn publish_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) = exchange.declare(exchange.new("p_exchange"), channel)

  let assert Ok(_) = queue.declare(queue.new("p_queue"), channel)

  let assert Ok(_) =
    publisher.publish(
      channel: channel,
      exchange: "p_exchange",
      routing_key: "",
      payload: "test",
      options: [],
    )
}

pub fn publish_with_options_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) = exchange.declare(exchange.new("pwo_exchange"), channel)

  let assert Ok(_) = queue.declare(queue.new("pwo_queue"), channel)

  let headers =
    publisher.headers_from_list([
      #("string_key", publisher.StringHeader("value")),
      #("bool_key", publisher.BoolHeader(True)),
    ])

  let assert Ok(_) =
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
}

pub fn subscribe_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) = exchange.declare(exchange.new("consume_exchange"), channel)
  let assert Ok(_) = queue.declare(queue.new("consume_queue"), channel)

  let assert Ok(_) =
    queue.bind(
      channel: channel,
      queue: "consume_queue",
      exchange: "consume_exchange",
      routing_key: "",
    )

  let assert Ok(_) =
    publisher.publish(
      channel: channel,
      exchange: "consume_exchange",
      routing_key: "",
      payload: "payload",
      options: [],
    )

  let assert Ok(_) =
    queue.subscribe(
      channel: channel,
      queue: "consume_queue",
      callback: fn(payload, _) {
        assert payload.payload == "payload"
      },
    )
  process.sleep(1000)
}

pub fn unsubscribe_test() {
  let assert Ok(value) = carotte.start(carotte.default_client())
  let client = value

  let assert Ok(value) = channel.open_channel(client)
  let channel = value

  let assert Ok(_) =
    exchange.declare(exchange.new("unsubscribe_exchange"), channel)
  let assert Ok(_) = queue.declare(queue.new("unsubscribe_queue"), channel)

  let assert Ok(_) =
    queue.bind(
      channel: channel,
      queue: "unsubscribe_queue",
      exchange: "unsubscribe_exchange",
      routing_key: "",
    )

  let assert Ok(_) =
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

  let assert Ok(value) =
    queue.subscribe(
      channel: channel,
      queue: "unsubscribe_queue",
      callback: fn(payload, _) {
        assert payload.payload == "payload"
      },
    )
  let consumer_tag = value

  let assert Ok(_) = queue.unsubscribe(channel, consumer_tag)
  process.sleep(1000)
}
