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
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)

  let assert Ok(Nil) =
    exchange.new("declare_exchange")
    |> exchange.with_type(exchange.Direct)
    |> exchange.as_durable()
    |> exchange.as_internal()
    |> exchange.with_auto_delete()
    |> exchange.declare(channel)
}

pub fn delete_exchange_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)

  let assert Ok(Nil) =
    exchange.new("delete_exchange")
    |> exchange.with_type(exchange.Direct)
    |> exchange.as_durable()
    |> exchange.as_internal()
    |> exchange.with_auto_delete()
    |> exchange.declare(channel)

  exchange.delete(channel, "delete_exchange", if_unused: False)
}

pub fn bind_exchanges_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)

  let assert Ok(Nil) =
    exchange.new("bind_exchange_source")
    |> exchange.with_type(exchange.Direct)
    |> exchange.declare(channel)

  let assert Ok(Nil) =
    exchange.new("bind_exchange_destination")
    |> exchange.with_type(exchange.Direct)
    |> exchange.declare(channel)

  let assert Ok(Nil) =
    exchange.bind(
      channel: channel,
      source: "bind_exchange_source",
      destination: "bind_exchange_destination",
      routing_key: "test",
    )
  let assert Ok(Nil) =
    exchange.bind(
      channel: channel,
      source: "bind_exchange_source",
      destination: "bind_exchange_destination",
      routing_key: "another",
    )
}

pub fn unbind_exchanges_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)

  assert Ok(Nil)
    == exchange.new("unbind_exchange_source")
    |> exchange.with_type(exchange.Direct)
    |> exchange.declare(channel)

  assert Ok(Nil)
    == exchange.new("unbind_exchange_destination")
    |> exchange.with_type(exchange.Direct)
    |> exchange.declare(channel)

  assert Ok(Nil)
    == exchange.bind(
      channel: channel,
      source: "unbind_exchange_source",
      destination: "unbind_exchange_destination",
      routing_key: "test",
    )

  assert Ok(Nil)
    == exchange.unbind(
      channel: channel,
      source: "unbind_exchange_source",
      destination: "unbind_exchange_destination",
      routing_key: "test",
    )
}

pub fn declare_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)

  assert Ok(queue.DeclaredQueue("declare_queue", 0, 0))
    == queue.declare(queue.new("declare_queue"), channel)
}

pub fn declare_queue_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)

  assert Ok(Nil)
    == queue.declare_async(queue.new("declare_queue_async"), channel)
}

pub fn delete_queue_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)

  let assert Ok(_) = queue.declare(queue.new("delete_queue"), channel)

  assert Ok(0) == queue.delete(channel, "delete_queue", False, False)
}

pub fn bind_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)

  let assert Ok(_) = queue.declare(queue.new("bind_queue"), channel)

  let assert Ok(Nil) =
    exchange.declare(exchange.new("bind_queue_exchange"), channel)

  let assert Ok(Nil) =
    queue.bind(
      channel: channel,
      queue: "bind_queue",
      exchange: "bind_queue_exchange",
      routing_key: "test",
    )
}

pub fn unbind_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)
  let assert Ok(_) = queue.declare(queue.new("unbind_queue"), channel)
  let assert Ok(Nil) =
    exchange.declare(exchange.new("unbind_queue_exchange"), channel)
  let assert Ok(Nil) =
    queue.bind(
      channel: channel,
      queue: "unbind_queue",
      exchange: "unbind_queue_exchange",
      routing_key: "test",
    )

  assert Ok(Nil)
    == queue.unbind(
      channel: channel,
      queue: "unbind_queue",
      exchange: "unbind_queue_exchange",
      routing_key: "test",
    )
}

pub fn purge_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)
  let assert Ok(_) = queue.declare(queue.new("purge_queue"), channel)

  assert Ok(0) == queue.purge(channel, "purge_queue")
}

pub fn purge_queue_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)
  let assert Ok(_) = queue.declare(queue.new("purge_queue_async"), channel)

  assert Ok(Nil) == queue.purge_async(channel, "purge_queue_async")
}

pub fn queue_status_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)
  let assert Ok(_) = queue.declare(queue.new("queue_status"), channel)

  assert Ok(queue.DeclaredQueue("queue_status", 0, 0))
    == queue.status(channel, "queue_status")
}

pub fn publish_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)
  let assert Ok(Nil) = exchange.declare(exchange.new("p_exchange"), channel)
  let assert Ok(_) = queue.declare(queue.new("p_queue"), channel)

  assert Ok(Nil)
    == publisher.publish(
      channel: channel,
      exchange: "p_exchange",
      routing_key: "",
      payload: "test",
      options: [],
    )
}

pub fn publish_with_options_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)
  let assert Ok(Nil) = exchange.declare(exchange.new("pwo_exchange"), channel)
  let assert Ok(_) = queue.declare(queue.new("pwo_queue"), channel)
  let headers =
    publisher.headers_from_list([
      #("string_key", publisher.StringHeader("value")),
      #("bool_key", publisher.BoolHeader(True)),
    ])

  assert Ok(Nil)
    == publisher.publish(
      channel: channel,
      exchange: "pwo_exchange",
      routing_key: "",
      payload: "publish with options",
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
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)
  let assert Ok(_) = exchange.declare(exchange.new("consume_exchange"), channel)
  // Delete the queue first to ensure it's clean
  let _ = queue.delete(channel, "consume_queue", False, False)
  let assert Ok(_) = queue.declare(queue.new("consume_queue"), channel)
  let assert Ok(_) =
    queue.bind(
      channel: channel,
      queue: "consume_queue",
      exchange: "consume_exchange",
      routing_key: "",
    )

  let message_subject = process.new_subject()

  let assert Ok(_) =
    queue.subscribe(
      channel: channel,
      queue: "consume_queue",
      callback: fn(payload, _) {
        process.send(message_subject, payload.payload)
        Nil
      },
    )
  process.sleep(1000)

  let assert Ok(_) =
    publisher.publish(
      channel: channel,
      exchange: "consume_exchange",
      routing_key: "",
      payload: "payload1",
      options: [],
    )
  let assert Ok(_) =
    publisher.publish(
      channel: channel,
      exchange: "consume_exchange",
      routing_key: "",
      payload: "payload2",
      options: [],
    )
  process.sleep(1000)

  let assert Ok("payload1") = process.receive(message_subject, 2000)
  let assert Ok("payload2") = process.receive(message_subject, 2000)
}

pub fn unsubscribe_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = channel.open_channel(client)
  let assert Ok(Nil) =
    exchange.declare(exchange.new("unsubscribe_exchange"), channel)
  let assert Ok(_) = queue.declare(queue.new("unsubscribe_queue"), channel)
  let assert Ok(Nil) =
    queue.bind(
      channel: channel,
      queue: "unsubscribe_queue",
      exchange: "unsubscribe_exchange",
      routing_key: "",
    )
  let assert Ok(Nil) =
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
      callback: fn(_, _) { Nil },
    )
  let consumer_tag = value

  let assert Ok(_) = queue.unsubscribe(channel, consumer_tag)
}

pub fn auth_failure_test() {
  let assert Error(value) =
    carotte.default_client()
    |> carotte.with_password("wrong")
    |> carotte.start()
  assert value
    == carotte.AuthFailure(
      "ACCESS_REFUSED - Login was refused using authentication mechanism PLAIN. For details see the broker logfile.",
    )
}
