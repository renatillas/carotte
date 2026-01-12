import carotte
import gleam/bit_array
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/static_supervisor
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import gleeunit

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// CONNECTION STATE FUNCTIONS
// =============================================================================

pub fn is_connected_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())

  // Should be connected after start
  assert carotte.is_connected(client) == True

  // Close the connection
  let assert Ok(Nil) = carotte.close(client)

  // Should not be connected after close
  assert carotte.is_connected(client) == False
}

pub fn connection_state_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())

  // Should be Connected after start
  assert carotte.connection_state(client) == carotte.Connected

  // Close the connection
  let assert Ok(Nil) = carotte.close(client)

  // Should be Disconnected after close
  let assert carotte.Disconnected(carotte.ConnectionProcessNotAlive) =
    carotte.connection_state(client)
}

pub fn reconnect_success_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())

  // Verify connected
  assert carotte.is_connected(client) == True

  // Close the connection
  let assert Ok(Nil) = carotte.close(client)

  // Verify disconnected
  assert carotte.is_connected(client) == False

  // Reconnect should succeed
  let assert Ok(new_client) = carotte.reconnect(client)

  // New client should be connected
  assert carotte.is_connected(new_client) == True

  // Cleanup
  let assert Ok(Nil) = carotte.close(new_client)
}

pub fn declare_exchange_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  assert Ok(Nil)
    == carotte.Exchange(
      ..carotte.exchange("declare_exchange"),
      exchange_type: carotte.Direct,
      durable: True,
      internal: True,
      auto_delete: True,
    )
    |> carotte.declare_exchange(channel)
}

pub fn delete_exchange_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  assert Ok(Nil)
    == carotte.Exchange(
      ..carotte.exchange("delete_exchange"),
      exchange_type: carotte.Direct,
      durable: True,
      internal: True,
      auto_delete: True,
    )
    |> carotte.declare_exchange(channel)

  assert Ok(Nil)
    == carotte.delete_exchange(
      channel:,
      exchange: "delete_exchange",
      if_unused: False,
    )
}

pub fn bind_exchanges_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Direct is the default exchange type
  assert Ok(Nil)
    == carotte.exchange("bind_exchange_source")
    |> carotte.declare_exchange(channel)

  assert Ok(Nil)
    == carotte.exchange("bind_exchange_destination")
    |> carotte.declare_exchange(channel)

  assert Ok(Nil)
    == carotte.bind_exchange(
      channel: channel,
      source: "bind_exchange_source",
      destination: "bind_exchange_destination",
      routing_key: "test",
    )
  assert Ok(Nil)
    == carotte.bind_exchange(
      channel: channel,
      source: "bind_exchange_source",
      destination: "bind_exchange_destination",
      routing_key: "another",
    )
}

pub fn unbind_exchanges_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  assert Ok(Nil)
    == carotte.exchange("unbind_exchange_source")
    |> carotte.declare_exchange(channel)

  assert Ok(Nil)
    == carotte.exchange("unbind_exchange_destination")
    |> carotte.declare_exchange(channel)

  assert Ok(Nil)
    == carotte.bind_exchange(
      channel: channel,
      source: "unbind_exchange_source",
      destination: "unbind_exchange_destination",
      routing_key: "test",
    )

  assert Ok(Nil)
    == carotte.unbind_exchange(
      channel: channel,
      source: "unbind_exchange_source",
      destination: "unbind_exchange_destination",
      routing_key: "test",
    )
}

pub fn declare_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  assert Ok(carotte.Queue("declare_queue", 0, 0))
    == carotte.declare_queue(carotte.default_queue("declare_queue"), channel)
}

pub fn declare_queue_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  assert Ok(Nil)
    == carotte.declare_queue_async(
      carotte.default_queue("declare_queue_async"),
      channel,
    )
}

pub fn delete_queue_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("delete_queue"), channel)

  assert Ok(0)
    == carotte.delete_queue(
      channel:,
      queue: "delete_queue",
      if_unused: False,
      if_empty: False,
    )
}

pub fn bind_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("bind_queue"), channel)

  let assert Ok(Nil) =
    carotte.declare_exchange(carotte.exchange("bind_queue_exchange"), channel)

  let assert Ok(Nil) =
    carotte.bind_queue(
      channel: channel,
      queue: "bind_queue",
      exchange: "bind_queue_exchange",
      routing_key: "test",
    )
}

pub fn unbind_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("unbind_queue"), channel)
  let assert Ok(Nil) =
    carotte.declare_exchange(carotte.exchange("unbind_queue_exchange"), channel)
  let assert Ok(Nil) =
    carotte.bind_queue(
      channel: channel,
      queue: "unbind_queue",
      exchange: "unbind_queue_exchange",
      routing_key: "test",
    )

  assert Ok(Nil)
    == carotte.unbind_queue(
      channel: channel,
      queue: "unbind_queue",
      exchange: "unbind_queue_exchange",
      routing_key: "test",
    )
}

pub fn purge_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("purge_queue"), channel)

  assert Ok(0) == carotte.purge_queue(channel:, queue: "purge_queue")
}

pub fn purge_queue_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("purge_queue_async"), channel)

  assert Ok(Nil)
    == carotte.purge_queue_async(channel:, queue: "purge_queue_async")
}

pub fn queue_status_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("queue_status"), channel)

  assert Ok(carotte.Queue("queue_status", 0, 0))
    == carotte.queue_status(channel:, queue: "queue_status")
}

pub fn publish_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(Nil) =
    carotte.declare_exchange(carotte.exchange("p_exchange"), channel)
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("p_queue"), channel)

  assert Ok(Nil)
    == carotte.publish(
      channel: channel,
      exchange: "p_exchange",
      routing_key: "",
      payload: <<"test">>,
      options: [],
    )
}

pub fn publish_with_options_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(Nil) =
    carotte.declare_exchange(carotte.exchange("pwo_exchange"), channel)
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("pwo_queue"), channel)
  let headers =
    carotte.headers_from_list([
      #("string_key", carotte.StringHeader("value")),
      #("bool_key", carotte.BoolHeader(True)),
    ])

  assert Ok(Nil)
    == carotte.publish(
      channel: channel,
      exchange: "pwo_exchange",
      routing_key: "",
      payload: <<"publish with options">>,
      options: [
        carotte.Mandatory(True),
        carotte.ContentType("text/plain"),
        carotte.ContentEncoding("utf-8"),
        carotte.MessageHeaders(headers),
        carotte.Persistent(True),
        carotte.CorrelationId("123"),
        carotte.Priority(9),
        carotte.Expiration(duration.seconds(1)),
        carotte.MessageId("123"),
        carotte.Timestamp(timestamp.from_unix_seconds(123)),
        carotte.Type("test"),
      ],
    )
}

pub fn subscribe_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(_) =
    carotte.declare_exchange(carotte.exchange("consume_exchange"), channel)
  // Delete the queue first to ensure it's clean
  let _ =
    carotte.delete_queue(
      channel:,
      queue: "consume_queue",
      if_unused: False,
      if_empty: False,
    )
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("consume_queue"), channel)
  let assert Ok(_) =
    carotte.bind_queue(
      channel: channel,
      queue: "consume_queue",
      exchange: "consume_exchange",
      routing_key: "",
    )

  let message_subject = process.new_subject()

  // Start the supervisor
  let consumers = process.new_name("subscribe_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel: channel,
      queue: "consume_queue",
      callback: fn(payload, _) {
        process.send(message_subject, payload.payload)
        Nil
      },
    )
  process.sleep(1000)

  let assert Ok(_) =
    carotte.publish(
      channel: channel,
      exchange: "consume_exchange",
      routing_key: "",
      payload: <<"payload1">>,
      options: [],
    )
  let assert Ok(_) =
    carotte.publish(
      channel: channel,
      exchange: "consume_exchange",
      routing_key: "",
      payload: <<"payload2">>,
      options: [],
    )
  process.sleep(1000)

  let assert Ok(<<"payload1">>) = process.receive(message_subject, 2000)
  let assert Ok(<<"payload2">>) = process.receive(message_subject, 2000)
}

pub fn unsubscribe_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(Nil) =
    carotte.declare_exchange(carotte.exchange("unsubscribe_exchange"), channel)
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("unsubscribe_queue"), channel)
  let assert Ok(Nil) =
    carotte.bind_queue(
      channel: channel,
      queue: "unsubscribe_queue",
      exchange: "unsubscribe_exchange",
      routing_key: "",
    )
  let assert Ok(Nil) =
    carotte.publish(
      channel: channel,
      exchange: "unsubscribe_exchange",
      routing_key: "",
      payload: <<"payload">>,
      options: [
        carotte.Mandatory(True),
        carotte.ContentType("text/plain"),
        carotte.ContentEncoding("utf-8"),
        carotte.Persistent(True),
        carotte.CorrelationId("123"),
        carotte.Priority(9),
        carotte.Expiration(duration.seconds(1)),
        carotte.MessageId("123"),
        carotte.Timestamp(timestamp.from_unix_seconds(123)),
        carotte.Type("test"),
      ],
    )

  // Start the supervisor
  let consumers = process.new_name("unsubscribe_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let assert Ok(consumer_tag) =
    carotte.subscribe(
      connection,
      channel: channel,
      queue: "unsubscribe_queue",
      callback: fn(_, _) { Nil },
    )

  let assert Ok(_) = carotte.unsubscribe(channel: channel, consumer_tag:)
}

pub fn auth_failure_test() {
  let assert Error(value) =
    carotte.ClientConfig(..carotte.default_client(), password: "wrong")
    |> carotte.start()
  assert value
    == carotte.ConnectionAuthFailure(
      "ACCESS_REFUSED - Login was refused using authentication mechanism PLAIN. For details see the broker logfile.",
    )
}

pub fn receive_headers_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(_) =
    carotte.declare_exchange(carotte.exchange("headers_test_exchange"), channel)
  // Delete the queue first to ensure it's clean
  let _ =
    carotte.delete_queue(
      channel:,
      queue: "headers_test_queue",
      if_unused: False,
      if_empty: False,
    )
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("headers_test_queue"), channel)
  let assert Ok(_) =
    carotte.bind_queue(
      channel: channel,
      queue: "headers_test_queue",
      exchange: "headers_test_exchange",
      routing_key: "",
    )

  let headers_subject = process.new_subject()

  // Start the supervisor
  let consumers = process.new_name("headers_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel: channel,
      queue: "headers_test_queue",
      callback: fn(payload, _) {
        let headers = carotte.headers_to_list(payload.headers)
        process.send(headers_subject, headers)
        Nil
      },
    )
  process.sleep(500)

  // Publish message with headers
  let headers =
    carotte.headers_from_list([
      #("string_key", carotte.StringHeader("hello")),
      #("int_key", carotte.IntHeader(42)),
      #("bool_key", carotte.BoolHeader(True)),
    ])

  let assert Ok(_) =
    carotte.publish(
      channel: channel,
      exchange: "headers_test_exchange",
      routing_key: "",
      payload: <<"test payload">>,
      options: [carotte.MessageHeaders(headers)],
    )
  process.sleep(500)

  let assert Ok(received_headers) = process.receive(headers_subject, 2000)

  // Verify headers were received correctly (order may vary)
  assert list.length(received_headers) == 3

  let assert Ok(#(_, carotte.StringHeader("hello"))) =
    list.find(received_headers, fn(h) { h.0 == "string_key" })

  let assert Ok(#(_, carotte.IntHeader(42))) =
    list.find(received_headers, fn(h) { h.0 == "int_key" })

  let assert Ok(#(_, carotte.BoolHeader(True))) =
    list.find(received_headers, fn(h) { h.0 == "bool_key" })
}

pub fn receive_float_header_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(_) =
    carotte.declare_exchange(
      carotte.exchange("float_headers_test_exchange"),
      channel,
    )
  // Delete the queue first to ensure it's clean
  let _ =
    carotte.delete_queue(
      channel:,
      queue: "float_headers_test_queue",
      if_unused: False,
      if_empty: False,
    )
  let assert Ok(_) =
    carotte.declare_queue(
      carotte.default_queue("float_headers_test_queue"),
      channel,
    )
  let assert Ok(_) =
    carotte.bind_queue(
      channel: channel,
      queue: "float_headers_test_queue",
      exchange: "float_headers_test_exchange",
      routing_key: "",
    )

  let headers_subject = process.new_subject()

  // Start the supervisor
  let consumers = process.new_name("float_headers_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel: channel,
      queue: "float_headers_test_queue",
      callback: fn(payload, _) {
        let headers = carotte.headers_to_list(payload.headers)
        process.send(headers_subject, headers)
        Nil
      },
    )
  process.sleep(500)

  // Publish message with float header
  let headers =
    carotte.headers_from_list([
      #("float_key", carotte.FloatHeader(3.14159)),
      #("negative_float", carotte.FloatHeader(-42.5)),
    ])

  let assert Ok(_) =
    carotte.publish(
      channel: channel,
      exchange: "float_headers_test_exchange",
      routing_key: "",
      payload: <<"test payload with float">>,
      options: [carotte.MessageHeaders(headers)],
    )
  process.sleep(500)

  let assert Ok(received_headers) = process.receive(headers_subject, 2000)

  // Verify float headers were received correctly
  assert list.length(received_headers) == 2

  let assert Ok(#(_, carotte.FloatHeader(val1))) =
    list.find(received_headers, fn(h) { h.0 == "float_key" })
  // Float comparison with tolerance
  assert val1 >. 3.14 && val1 <. 3.15

  let assert Ok(#(_, carotte.FloatHeader(val2))) =
    list.find(received_headers, fn(h) { h.0 == "negative_float" })
  assert val2 <. -42.0 && val2 >. -43.0
}

pub fn receive_list_header_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(_) =
    carotte.declare_exchange(
      carotte.exchange("list_headers_test_exchange"),
      channel,
    )
  // Delete the queue first to ensure it's clean
  let _ =
    carotte.delete_queue(
      channel:,
      queue: "list_headers_test_queue",
      if_unused: False,
      if_empty: False,
    )
  let assert Ok(_) =
    carotte.declare_queue(
      carotte.default_queue("list_headers_test_queue"),
      channel,
    )
  let assert Ok(_) =
    carotte.bind_queue(
      channel: channel,
      queue: "list_headers_test_queue",
      exchange: "list_headers_test_exchange",
      routing_key: "",
    )

  let headers_subject = process.new_subject()

  // Start the supervisor
  let consumers = process.new_name("list_headers_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel: channel,
      queue: "list_headers_test_queue",
      callback: fn(payload, _) {
        let headers = carotte.headers_to_list(payload.headers)
        process.send(headers_subject, headers)
        Nil
      },
    )
  process.sleep(500)

  // Publish message with list header containing mixed types
  let headers =
    carotte.headers_from_list([
      #(
        "tags",
        carotte.ListHeader([
          carotte.StringHeader("tag1"),
          carotte.StringHeader("tag2"),
          carotte.StringHeader("tag3"),
        ]),
      ),
      #(
        "numbers",
        carotte.ListHeader([
          carotte.IntHeader(1),
          carotte.IntHeader(2),
          carotte.IntHeader(3),
        ]),
      ),
    ])

  let assert Ok(_) =
    carotte.publish(
      channel: channel,
      exchange: "list_headers_test_exchange",
      routing_key: "",
      payload: <<"test payload with list">>,
      options: [carotte.MessageHeaders(headers)],
    )
  process.sleep(500)

  let assert Ok(received_headers) = process.receive(headers_subject, 2000)

  // Verify list headers were received correctly
  assert list.length(received_headers) == 2

  let assert Ok(#(_, carotte.ListHeader(tags))) =
    list.find(received_headers, fn(h) { h.0 == "tags" })
  assert list.length(tags) == 3
  let assert [
    carotte.StringHeader("tag1"),
    carotte.StringHeader("tag2"),
    carotte.StringHeader("tag3"),
  ] = tags

  let assert Ok(#(_, carotte.ListHeader(numbers))) =
    list.find(received_headers, fn(h) { h.0 == "numbers" })
  assert list.length(numbers) == 3
  let assert [carotte.IntHeader(1), carotte.IntHeader(2), carotte.IntHeader(3)] =
    numbers
}

pub fn declare_queue_with_auto_generated_name_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Declare a queue with an empty name - RabbitMQ should generate one
  let assert Ok(carotte.Queue(name:, message_count: 0, consumer_count: 0)) =
    carotte.QueueConfig(
      ..carotte.default_queue(""),
      exclusive: True,
      auto_delete: True,
    )
    |> carotte.declare_queue(channel)

  assert name != ""
  // RabbitMQ auto-generated names start with "amq.gen-"
  assert string.starts_with(name, "amq.gen-")
}

/// Integration test using the proper supervised API pattern.
/// This is the recommended way to use carotte in production.
pub fn supervised_consumer_integration_test() {
  // 1. Create a RabbitMQ connection and channel
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // 2. Set up queue and exchange
  let assert Ok(_) =
    carotte.declare_queue(
      carotte.default_queue("supervised_test_queue"),
      channel,
    )
  let assert Ok(_) =
    carotte.purge_queue(channel:, queue: "supervised_test_queue")
  let assert Ok(_) =
    carotte.declare_exchange(
      carotte.exchange("supervised_test_exchange"),
      channel,
    )
  let assert Ok(_) =
    carotte.bind_queue(
      channel:,
      queue: "supervised_test_queue",
      exchange: "supervised_test_exchange",
      routing_key: "test.key",
    )

  // 3. Create a name for the consumer supervisor (done once at app startup)
  let consumers_name: process.Name(carotte.ConsumerSupervisorMessage) =
    process.new_name("test_consumers")

  // 4. Create the child specification using the supervised API
  let consumer_supervisor_spec = carotte.consumer_supervised(consumers_name)

  // 5. Start a static supervisor with the consumer supervisor as a child
  let assert Ok(_supervisor) =
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.add(consumer_supervisor_spec)
    |> static_supervisor.start()

  // Give the supervisor time to start
  process.sleep(100)

  // 6. Get reference to the consumer supervisor by name
  let connection = carotte.named_consumer(consumers_name)

  // 7. Set up message receiving
  let message_subject = process.new_subject()

  // 8. Subscribe to the queue using the supervised consumer supervisor
  let assert Ok(consumer_tag) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "supervised_test_queue",
      callback: fn(payload, _deliver) {
        process.send(message_subject, payload.payload)
        Nil
      },
    )

  // 9. Publish a test message
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "supervised_test_exchange",
      routing_key: "test.key",
      payload: <<"Hello from supervised test!">>,
      options: [],
    )

  // 10. Verify the message was received
  let assert Ok(<<"Hello from supervised test!">>) =
    process.receive(message_subject, 2000)

  // 11. Clean up - unsubscribe
  let assert Ok(_) = carotte.unsubscribe(channel:, consumer_tag:)

  // 12. Close connection
  let assert Ok(_) = carotte.close(client)
}

/// Integration test demonstrating the factory supervisor's ability to
/// dynamically manage multiple consumers across different queues.
/// This is the key feature of factory supervisors - dynamic child management.
pub fn factory_supervisor_multiple_consumers_test() {
  // 1. Connect to RabbitMQ
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // 2. Set up two separate queues with their exchanges
  let queue1 = "factory_test_queue_1"
  let queue2 = "factory_test_queue_2"
  let exchange1 = "factory_test_exchange_1"
  let exchange2 = "factory_test_exchange_2"

  // Declare and purge queue 1
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue(queue1), channel)
  let assert Ok(_) = carotte.purge_queue(channel:, queue: queue1)
  let assert Ok(_) =
    carotte.declare_exchange(carotte.exchange(exchange1), channel)
  let assert Ok(_) =
    carotte.bind_queue(
      channel:,
      queue: queue1,
      exchange: exchange1,
      routing_key: "",
    )

  // Declare and purge queue 2
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue(queue2), channel)
  let assert Ok(_) = carotte.purge_queue(channel:, queue: queue2)
  let assert Ok(_) =
    carotte.declare_exchange(carotte.exchange(exchange2), channel)
  let assert Ok(_) =
    carotte.bind_queue(
      channel:,
      queue: queue2,
      exchange: exchange2,
      routing_key: "",
    )

  // 3. Create a single consumer supervisor (factory supervisor)
  // This supervisor will manage multiple consumer children dynamically
  let consumers = process.new_name("factory_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  // 4. Set up subjects to receive messages from each consumer
  let subject1 = process.new_subject()
  let subject2 = process.new_subject()

  // 5. Dynamically add first consumer to queue 1
  let assert Ok(consumer_tag1) =
    carotte.subscribe(
      connection,
      channel:,
      queue: queue1,
      callback: fn(payload, _) {
        process.send(subject1, <<"q1:", payload.payload:bits>>)
      },
    )

  // 6. Dynamically add second consumer to queue 2
  let assert Ok(consumer_tag2) =
    carotte.subscribe(
      connection,
      channel:,
      queue: queue2,
      callback: fn(payload, _) {
        process.send(subject2, <<"q2:", payload.payload:bits>>)
      },
    )

  // Give consumers time to start
  process.sleep(200)

  // 7. Publish messages to both queues
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: exchange1,
      routing_key: "",
      payload: <<"msg1">>,
      options: [],
    )
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: exchange2,
      routing_key: "",
      payload: <<"msg2">>,
      options: [],
    )

  // 8. Verify both consumers received their messages
  let assert Ok(<<"q1:msg1">>) = process.receive(subject1, 2000)
  let assert Ok(<<"q2:msg2">>) = process.receive(subject2, 2000)

  // 9. Unsubscribe the first consumer while keeping the second active
  let assert Ok(_) = carotte.unsubscribe(channel:, consumer_tag: consumer_tag1)
  process.sleep(100)

  // 10. Publish another message to queue 2 - should still work
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: exchange2,
      routing_key: "",
      payload: <<"msg3">>,
      options: [],
    )

  // 11. Verify second consumer still receives messages
  let assert Ok(<<"q2:msg3">>) = process.receive(subject2, 2000)

  // 12. Add a third consumer to queue 1 (demonstrating dynamic addition)
  let subject3 = process.new_subject()
  let assert Ok(consumer_tag3) =
    carotte.subscribe(
      connection,
      channel:,
      queue: queue1,
      callback: fn(payload, _) {
        process.send(subject3, <<"q1_new:", payload.payload:bits>>)
      },
    )
  process.sleep(100)

  // 13. Publish to queue 1 again - new consumer should receive it
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: exchange1,
      routing_key: "",
      payload: <<"msg4">>,
      options: [],
    )

  let assert Ok(<<"q1_new:msg4">>) = process.receive(subject3, 2000)

  // 14. Clean up - unsubscribe remaining consumers
  let assert Ok(_) = carotte.unsubscribe(channel:, consumer_tag: consumer_tag2)
  let assert Ok(_) = carotte.unsubscribe(channel:, consumer_tag: consumer_tag3)

  // 15. Shutdown supervisor and close connection
  let assert Ok(_) = carotte.close(client)
}

/// Test that factory supervisor handles manual ack mode correctly
/// with multiple consumers managed by the same supervisor.
pub fn factory_supervisor_manual_ack_test() {
  // 1. Connect
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // 2. Set up queue
  let queue = "factory_manual_ack_queue"
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue(queue), channel)
  let assert Ok(_) = carotte.purge_queue(channel:, queue:)

  // 3. Start factory supervisor
  let consumers = process.new_name("manual_ack_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  // 4. Set up subjects
  let received = process.new_subject()

  // 5. Subscribe with manual ack
  let assert Ok(_consumer) =
    carotte.subscribe_with_options(
      connection,
      channel:,
      queue:,
      options: [carotte.AutoAck(False)],
      callback: fn(payload, deliver) {
        process.send(received, payload.payload)
        // Manually acknowledge
        let assert Ok(_) = carotte.ack(channel, deliver.delivery_tag, False)
        Nil
      },
    )

  process.sleep(100)

  // 6. Publish directly to queue
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "",
      routing_key: queue,
      payload: <<"manual_ack_msg">>,
      options: [],
    )

  // 7. Verify message was received and acked
  let assert Ok(<<"manual_ack_msg">>) = process.receive(received, 2000)

  // 8. Verify queue is empty (message was acked)
  process.sleep(100)
  let assert Ok(carotte.Queue(_, 0, _)) = carotte.queue_status(channel:, queue:)

  // 9. Cleanup
  let assert Ok(_) = carotte.close(client)
}

// =============================================================================
// EXCHANGE TYPE TESTS
// =============================================================================

pub fn fanout_exchange_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Declare a fanout exchange
  let assert Ok(Nil) =
    carotte.Exchange(
      ..carotte.exchange("fanout_test_exchange"),
      exchange_type: carotte.Fanout,
    )
    |> carotte.declare_exchange(channel)

  // Declare two queues and bind them to the fanout exchange
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("fanout_queue_1"), channel)
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("fanout_queue_2"), channel)
  let assert Ok(_) = carotte.purge_queue(channel:, queue: "fanout_queue_1")
  let assert Ok(_) = carotte.purge_queue(channel:, queue: "fanout_queue_2")

  let assert Ok(Nil) =
    carotte.bind_queue(
      channel:,
      queue: "fanout_queue_1",
      exchange: "fanout_test_exchange",
      routing_key: "",
    )
  let assert Ok(Nil) =
    carotte.bind_queue(
      channel:,
      queue: "fanout_queue_2",
      exchange: "fanout_test_exchange",
      routing_key: "",
    )

  // Start consumers
  let consumers = process.new_name("fanout_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let subject1 = process.new_subject()
  let subject2 = process.new_subject()

  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "fanout_queue_1",
      callback: fn(payload, _) { process.send(subject1, payload.payload) },
    )
  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "fanout_queue_2",
      callback: fn(payload, _) { process.send(subject2, payload.payload) },
    )

  process.sleep(200)

  // Publish to fanout exchange - should go to BOTH queues
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "fanout_test_exchange",
      routing_key: "ignored",
      payload: <<"fanout message">>,
      options: [],
    )

  // Both consumers should receive the message
  let assert Ok(<<"fanout message">>) = process.receive(subject1, 2000)
  let assert Ok(<<"fanout message">>) = process.receive(subject2, 2000)

  let assert Ok(_) = carotte.close(client)
}

pub fn topic_exchange_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Declare a topic exchange
  let assert Ok(Nil) =
    carotte.Exchange(
      ..carotte.exchange("topic_test_exchange"),
      exchange_type: carotte.Topic,
    )
    |> carotte.declare_exchange(channel)

  // Declare queues with different topic patterns
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("topic_queue_all"), channel)
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("topic_queue_logs"), channel)
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("topic_queue_error"), channel)
  let assert Ok(_) = carotte.purge_queue(channel:, queue: "topic_queue_all")
  let assert Ok(_) = carotte.purge_queue(channel:, queue: "topic_queue_logs")
  let assert Ok(_) = carotte.purge_queue(channel:, queue: "topic_queue_error")

  // Bind with different patterns
  // # matches zero or more words
  let assert Ok(Nil) =
    carotte.bind_queue(
      channel:,
      queue: "topic_queue_all",
      exchange: "topic_test_exchange",
      routing_key: "#",
    )
  // *.logs matches any.logs
  let assert Ok(Nil) =
    carotte.bind_queue(
      channel:,
      queue: "topic_queue_logs",
      exchange: "topic_test_exchange",
      routing_key: "*.logs",
    )
  // error.* matches error.anything
  let assert Ok(Nil) =
    carotte.bind_queue(
      channel:,
      queue: "topic_queue_error",
      exchange: "topic_test_exchange",
      routing_key: "error.*",
    )

  // Start consumers
  let consumers = process.new_name("topic_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let subject_all = process.new_subject()
  let subject_logs = process.new_subject()
  let subject_error = process.new_subject()

  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "topic_queue_all",
      callback: fn(payload, _) { process.send(subject_all, payload.payload) },
    )
  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "topic_queue_logs",
      callback: fn(payload, _) { process.send(subject_logs, payload.payload) },
    )
  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "topic_queue_error",
      callback: fn(payload, _) { process.send(subject_error, payload.payload) },
    )

  process.sleep(200)

  // Publish with routing key "app.logs" - should match # and *.logs
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "topic_test_exchange",
      routing_key: "app.logs",
      payload: <<"app log message">>,
      options: [],
    )

  // Publish with routing key "error.critical" - should match # and error.*
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "topic_test_exchange",
      routing_key: "error.critical",
      payload: <<"error message">>,
      options: [],
    )

  // All queue gets both messages
  let assert Ok(<<"app log message">>) = process.receive(subject_all, 2000)
  let assert Ok(<<"error message">>) = process.receive(subject_all, 2000)

  // Logs queue gets app.logs
  let assert Ok(<<"app log message">>) = process.receive(subject_logs, 2000)
  // Error queue gets error.critical
  let assert Ok(<<"error message">>) = process.receive(subject_error, 2000)

  let assert Ok(_) = carotte.close(client)
}

pub fn headers_exchange_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Declare a headers exchange
  let assert Ok(Nil) =
    carotte.Exchange(
      ..carotte.exchange("headers_test_exchange_type"),
      exchange_type: carotte.Headers,
    )
    |> carotte.declare_exchange(channel)

  // For headers exchange, we need to use the AMQP-level arguments for binding
  // which isn't directly supported by the current API (bind_queue doesn't expose arguments)
  // But we can at least test that the exchange is created correctly
  // and basic message flow works

  let assert Ok(_) =
    carotte.declare_queue(
      carotte.default_queue("headers_exchange_queue"),
      channel,
    )
  let assert Ok(_) =
    carotte.purge_queue(channel:, queue: "headers_exchange_queue")

  // Bind with empty routing key (headers exchange ignores routing key)
  let assert Ok(Nil) =
    carotte.bind_queue(
      channel:,
      queue: "headers_exchange_queue",
      exchange: "headers_test_exchange_type",
      routing_key: "",
    )

  // Start consumer
  let consumers = process.new_name("headers_exchange_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let subject = process.new_subject()

  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "headers_exchange_queue",
      callback: fn(payload, _) { process.send(subject, payload.payload) },
    )

  process.sleep(200)

  // Publish with headers
  let headers =
    carotte.headers_from_list([#("x-match", carotte.StringHeader("all"))])

  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "headers_test_exchange_type",
      routing_key: "",
      payload: <<"headers exchange message">>,
      options: [carotte.MessageHeaders(headers)],
    )

  let assert Ok(<<"headers exchange message">>) = process.receive(subject, 2000)

  let assert Ok(_) = carotte.close(client)
}

// =============================================================================
// ASYNC OPERATIONS TESTS
// =============================================================================

pub fn declare_exchange_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Declare exchange asynchronously
  let assert Ok(Nil) =
    carotte.exchange("async_declare_exchange")
    |> carotte.declare_exchange_async(channel)

  // Small delay to let async operation complete
  process.sleep(100)

  // Verify exchange exists by redeclaring it synchronously
  let assert Ok(Nil) =
    carotte.exchange("async_declare_exchange")
    |> carotte.declare_exchange(channel)

  let assert Ok(_) = carotte.close(client)
}

pub fn delete_exchange_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // First declare an exchange
  let assert Ok(Nil) =
    carotte.exchange("async_delete_exchange")
    |> carotte.declare_exchange(channel)

  // Delete asynchronously
  let assert Ok(Nil) =
    carotte.delete_exchange_async(
      channel:,
      exchange: "async_delete_exchange",
      if_unused: False,
    )

  // Small delay
  process.sleep(100)

  // Need a new channel since the previous one might be affected
  let assert Ok(channel2) = carotte.open_channel(client)

  // Verify exchange is gone by trying to bind to it (should fail)
  let assert Ok(_) =
    carotte.declare_queue(
      carotte.default_queue("async_delete_test_queue"),
      channel2,
    )
  let result =
    carotte.bind_queue(
      channel: channel2,
      queue: "async_delete_test_queue",
      exchange: "async_delete_exchange",
      routing_key: "",
    )

  // Should fail because exchange doesn't exist
  let assert Error(carotte.QueueNotFound(_)) = result

  let assert Ok(_) = carotte.close(client)
}

pub fn bind_exchange_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Create source and destination exchanges
  let assert Ok(Nil) =
    carotte.exchange("async_bind_source")
    |> carotte.declare_exchange(channel)
  let assert Ok(Nil) =
    carotte.exchange("async_bind_dest")
    |> carotte.declare_exchange(channel)

  // Bind asynchronously
  let assert Ok(Nil) =
    carotte.bind_exchange_async(
      channel:,
      source: "async_bind_source",
      destination: "async_bind_dest",
      routing_key: "test.key",
    )

  process.sleep(100)

  // Verify binding works by publishing through the chain
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("async_bind_queue"), channel)
  let assert Ok(_) = carotte.purge_queue(channel:, queue: "async_bind_queue")
  let assert Ok(Nil) =
    carotte.bind_queue(
      channel:,
      queue: "async_bind_queue",
      exchange: "async_bind_dest",
      routing_key: "test.key",
    )

  let consumers = process.new_name("async_bind_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let subject = process.new_subject()
  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "async_bind_queue",
      callback: fn(payload, _) { process.send(subject, payload.payload) },
    )

  process.sleep(200)

  // Publish to source - should flow through to destination and then to queue
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "async_bind_source",
      routing_key: "test.key",
      payload: <<"async bind test">>,
      options: [],
    )

  let assert Ok(<<"async bind test">>) = process.receive(subject, 2000)

  let assert Ok(_) = carotte.close(client)
}

pub fn unbind_exchange_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Create and bind exchanges
  let assert Ok(Nil) =
    carotte.exchange("async_unbind_source")
    |> carotte.declare_exchange(channel)
  let assert Ok(Nil) =
    carotte.exchange("async_unbind_dest")
    |> carotte.declare_exchange(channel)
  let assert Ok(Nil) =
    carotte.bind_exchange(
      channel:,
      source: "async_unbind_source",
      destination: "async_unbind_dest",
      routing_key: "unbind.key",
    )

  // Unbind asynchronously
  let assert Ok(Nil) =
    carotte.unbind_exchange_async(
      channel:,
      source: "async_unbind_source",
      destination: "async_unbind_dest",
      routing_key: "unbind.key",
    )

  process.sleep(100)

  let assert Ok(_) = carotte.close(client)
}

pub fn bind_queue_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Create exchange and queue
  let assert Ok(Nil) =
    carotte.exchange("async_queue_bind_exchange")
    |> carotte.declare_exchange(channel)
  let assert Ok(_) =
    carotte.declare_queue(
      carotte.default_queue("async_queue_bind_queue"),
      channel,
    )
  let assert Ok(_) =
    carotte.purge_queue(channel:, queue: "async_queue_bind_queue")

  // Bind queue asynchronously
  let assert Ok(Nil) =
    carotte.bind_queue_async(
      channel:,
      queue: "async_queue_bind_queue",
      exchange: "async_queue_bind_exchange",
      routing_key: "async.route",
    )

  process.sleep(100)

  // Verify by consuming
  let consumers = process.new_name("async_queue_bind_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let subject = process.new_subject()
  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "async_queue_bind_queue",
      callback: fn(payload, _) { process.send(subject, payload.payload) },
    )

  process.sleep(200)

  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "async_queue_bind_exchange",
      routing_key: "async.route",
      payload: <<"async queue bind test">>,
      options: [],
    )

  let assert Ok(<<"async queue bind test">>) = process.receive(subject, 2000)

  let assert Ok(_) = carotte.close(client)
}

pub fn unsubscribe_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  let assert Ok(_) =
    carotte.declare_queue(
      carotte.default_queue("async_unsubscribe_queue"),
      channel,
    )
  let assert Ok(_) =
    carotte.purge_queue(channel:, queue: "async_unsubscribe_queue")

  let consumers = process.new_name("async_unsubscribe_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let assert Ok(consumer_tag) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "async_unsubscribe_queue",
      callback: fn(_, _) { Nil },
    )

  process.sleep(100)

  // Unsubscribe asynchronously
  let assert Ok(Nil) = carotte.unsubscribe_async(channel:, consumer_tag:)

  process.sleep(100)

  let assert Ok(_) = carotte.close(client)
}

pub fn delete_queue_async_full_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Create a queue
  let assert Ok(_) =
    carotte.declare_queue(
      carotte.default_queue("async_delete_queue_full"),
      channel,
    )

  // Delete asynchronously
  let assert Ok(Nil) =
    carotte.delete_queue_async(
      channel:,
      queue: "async_delete_queue_full",
      if_unused: False,
      if_empty: False,
    )

  process.sleep(100)

  // Verify queue is gone by trying to get status
  let assert Ok(ch2) = carotte.open_channel(client)
  let assert Error(carotte.QueueNotFound(_)) =
    carotte.queue_status(channel: ch2, queue: "async_delete_queue_full")

  let assert Ok(_) = carotte.close(client)
}

// =============================================================================
// MISSING PUBLISH OPTIONS TESTS
// =============================================================================

pub fn publish_with_reply_to_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("reply_to_queue"), channel)
  let assert Ok(_) = carotte.purge_queue(channel:, queue: "reply_to_queue")

  let consumers = process.new_name("reply_to_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let subject = process.new_subject()
  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "reply_to_queue",
      callback: fn(payload, _) {
        // Check if ReplyTo is in the properties
        let has_reply_to =
          list.any(payload.properties, fn(prop) {
            case prop {
              carotte.ReplyTo("my_reply_queue") -> True
              _ -> False
            }
          })
        process.send(subject, has_reply_to)
      },
    )

  process.sleep(200)

  // Publish with ReplyTo option
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "",
      routing_key: "reply_to_queue",
      payload: <<"test">>,
      options: [carotte.ReplyTo("my_reply_queue")],
    )

  let assert Ok(True) = process.receive(subject, 2000)

  let assert Ok(_) = carotte.close(client)
}

pub fn publish_with_user_id_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("user_id_queue"), channel)
  let assert Ok(_) = carotte.purge_queue(channel:, queue: "user_id_queue")

  let consumers = process.new_name("user_id_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let subject = process.new_subject()
  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "user_id_queue",
      callback: fn(payload, _) {
        let has_user_id =
          list.any(payload.properties, fn(prop) {
            case prop {
              carotte.UserId("guest") -> True
              _ -> False
            }
          })
        process.send(subject, has_user_id)
      },
    )

  process.sleep(200)

  // Publish with UserId option (must match connection user for RabbitMQ)
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "",
      routing_key: "user_id_queue",
      payload: <<"test">>,
      options: [carotte.UserId("guest")],
    )

  let assert Ok(True) = process.receive(subject, 2000)

  let assert Ok(_) = carotte.close(client)
}

pub fn publish_with_app_id_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("app_id_queue"), channel)
  let assert Ok(_) = carotte.purge_queue(channel:, queue: "app_id_queue")

  let consumers = process.new_name("app_id_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let subject = process.new_subject()
  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "app_id_queue",
      callback: fn(payload, _) {
        let has_app_id =
          list.any(payload.properties, fn(prop) {
            case prop {
              carotte.AppId("my_test_app") -> True
              _ -> False
            }
          })
        process.send(subject, has_app_id)
      },
    )

  process.sleep(200)

  // Publish with AppId option
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "",
      routing_key: "app_id_queue",
      payload: <<"test">>,
      options: [carotte.AppId("my_test_app")],
    )

  let assert Ok(True) = process.receive(subject, 2000)

  let assert Ok(_) = carotte.close(client)
}

// =============================================================================
// EMPTY HEADERS AND EDGE CASES
// =============================================================================

pub fn empty_headers_test() {
  let headers = carotte.empty_headers()
  let list = carotte.headers_to_list(headers)
  assert list == []
}

pub fn headers_roundtrip_test() {
  // Test that headers can be converted to list and back
  let original = [
    #("key1", carotte.StringHeader("value1")),
    #("key2", carotte.IntHeader(42)),
    #("key3", carotte.BoolHeader(True)),
    #("key4", carotte.FloatHeader(3.14)),
  ]

  let headers = carotte.headers_from_list(original)
  let result = carotte.headers_to_list(headers)

  // Verify all headers are present (order may differ)
  assert list.length(result) == 4

  let assert Ok(#(_, carotte.StringHeader("value1"))) =
    list.find(result, fn(h) { h.0 == "key1" })

  let assert Ok(#(_, carotte.IntHeader(42))) =
    list.find(result, fn(h) { h.0 == "key2" })

  let assert Ok(#(_, carotte.BoolHeader(True))) =
    list.find(result, fn(h) { h.0 == "key3" })

  let assert Ok(#(_, carotte.FloatHeader(f))) =
    list.find(result, fn(h) { h.0 == "key4" })
  assert f >. 3.13 && f <. 3.15
}

pub fn nested_list_headers_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  let assert Ok(_) =
    carotte.declare_queue(
      carotte.default_queue("nested_list_headers_queue"),
      channel,
    )
  let assert Ok(_) =
    carotte.purge_queue(channel:, queue: "nested_list_headers_queue")

  let consumers = process.new_name("nested_list_headers_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let headers_subject = process.new_subject()
  let assert Ok(_) =
    carotte.subscribe(
      connection,
      channel:,
      queue: "nested_list_headers_queue",
      callback: fn(payload, _) {
        let headers = carotte.headers_to_list(payload.headers)
        process.send(headers_subject, headers)
      },
    )

  process.sleep(200)

  // Create nested list headers
  let headers =
    carotte.headers_from_list([
      #(
        "nested",
        carotte.ListHeader([
          carotte.ListHeader([
            carotte.StringHeader("deep1"),
            carotte.StringHeader("deep2"),
          ]),
          carotte.IntHeader(999),
        ]),
      ),
    ])

  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "",
      routing_key: "nested_list_headers_queue",
      payload: <<"nested test">>,
      options: [carotte.MessageHeaders(headers)],
    )

  let assert Ok(received_headers) = process.receive(headers_subject, 2000)

  // Verify nested structure
  assert list.length(received_headers) == 1
  let assert Ok(#("nested", carotte.ListHeader(outer_list))) =
    list.find(received_headers, fn(h) { h.0 == "nested" })

  assert list.length(outer_list) == 2

  let assert Ok(_) = carotte.close(client)
}

// =============================================================================
// SUBSCRIBE WITH EMPTY OPTIONS (DEFAULT AUTO_ACK)
// =============================================================================

pub fn subscribe_with_empty_options_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("empty_options_queue"), channel)
  let assert Ok(_) = carotte.purge_queue(channel:, queue: "empty_options_queue")

  let consumers = process.new_name("empty_options_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let subject = process.new_subject()

  // Subscribe with empty options list - should default to auto_ack=True
  let assert Ok(consumer_tag) =
    carotte.subscribe_with_options(
      connection,
      channel:,
      queue: "empty_options_queue",
      options: [],
      callback: fn(payload, _) { process.send(subject, payload.payload) },
    )

  process.sleep(200)

  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: "",
      routing_key: "empty_options_queue",
      payload: <<"auto ack message">>,
      options: [],
    )

  let assert Ok(<<"auto ack message">>) = process.receive(subject, 2000)

  // Queue should be empty since auto_ack is enabled
  process.sleep(100)
  let assert Ok(carotte.Queue(_, 0, _)) =
    carotte.queue_status(channel:, queue: "empty_options_queue")

  let assert Ok(_) = carotte.unsubscribe(channel:, consumer_tag:)
  let assert Ok(_) = carotte.close(client)
}

// =============================================================================
// DURABLE AND AUTO-DELETE OPTIONS
// =============================================================================

pub fn durable_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Declare a durable queue
  let assert Ok(carotte.Queue("durable_test_queue", _, _)) =
    carotte.QueueConfig(
      ..carotte.default_queue("durable_test_queue"),
      durable: True,
    )
    |> carotte.declare_queue(channel)

  // Cleanup
  let assert Ok(_) =
    carotte.delete_queue(
      channel:,
      queue: "durable_test_queue",
      if_unused: False,
      if_empty: False,
    )

  let assert Ok(_) = carotte.close(client)
}

pub fn auto_delete_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Declare an auto-delete queue
  let assert Ok(carotte.Queue("auto_delete_test_queue", _, _)) =
    carotte.QueueConfig(
      ..carotte.default_queue("auto_delete_test_queue"),
      auto_delete: True,
    )
    |> carotte.declare_queue(channel)

  let assert Ok(_) = carotte.close(client)
}

pub fn durable_exchange_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Declare a durable exchange
  let assert Ok(Nil) =
    carotte.Exchange(..carotte.exchange("durable_test_exchange"), durable: True)
    |> carotte.declare_exchange(channel)

  // Cleanup
  let assert Ok(Nil) =
    carotte.delete_exchange(
      channel:,
      exchange: "durable_test_exchange",
      if_unused: False,
    )

  let assert Ok(_) = carotte.close(client)
}

pub fn internal_exchange_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Declare an internal exchange (can only receive messages from other exchanges)
  let assert Ok(Nil) =
    carotte.Exchange(
      ..carotte.exchange("internal_test_exchange"),
      internal: True,
    )
    |> carotte.declare_exchange(channel)

  // Cleanup
  let assert Ok(Nil) =
    carotte.delete_exchange(
      channel:,
      exchange: "internal_test_exchange",
      if_unused: False,
    )

  let assert Ok(_) = carotte.close(client)
}

// =============================================================================
// ACK / NACK / REJECT TESTS
// =============================================================================

pub fn manual_ack_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)
  let test_queue = carotte.default_queue("test_ack_queue")
  let assert Ok(_) = carotte.declare_queue(test_queue, ch)
  // Purge queue to ensure clean state
  let assert Ok(_) = carotte.purge_queue(channel: ch, queue: "test_ack_queue")
  let assert Ok(_) =
    carotte.declare_exchange(carotte.exchange("test_ack_exchange"), ch)
  let assert Ok(Nil) =
    carotte.bind_queue(
      channel: ch,
      queue: "test_ack_queue",
      exchange: "test_ack_exchange",
      routing_key: "",
    )
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "test_ack_exchange",
      routing_key: "",
      payload: <<"test message for ack">>,
      options: [],
    )

  let message_subject = process.new_subject()

  // Start the supervisor
  let consumers = process.new_name("manual_ack_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let assert Ok(_consumer) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_ack_queue",
      callback: fn(msg, deliver) {
        process.send(message_subject, msg.payload)
        // Acknowledge the message
        let assert Ok(Nil) = carotte.ack(ch, deliver.delivery_tag, False)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  // Verify message is received and processed
  let assert Ok(<<"test message for ack">>) =
    process.receive(message_subject, 1000)
}

pub fn ack_single_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)
  let test_queue = carotte.default_queue("test_ack_single_queue")
  let assert Ok(_) = carotte.declare_queue(test_queue, ch)
  // Purge queue to ensure clean state
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "test_ack_single_queue")
  let assert Ok(_) =
    carotte.declare_exchange(carotte.exchange("test_ack_single_exchange"), ch)
  let assert Ok(_) =
    carotte.bind_queue(
      channel: ch,
      queue: "test_ack_single_queue",
      exchange: "test_ack_single_exchange",
      routing_key: "",
    )

  // Publish two messages
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "test_ack_single_exchange",
      routing_key: "",
      payload: <<"message 1">>,
      options: [],
    )
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "test_ack_single_exchange",
      routing_key: "",
      payload: <<"message 2">>,
      options: [],
    )

  let message_subject = process.new_subject()

  // Start the supervisor
  let consumers = process.new_name("ack_single_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  // Subscribe and acknowledge each message individually
  let assert Ok(_consumer) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_ack_single_queue",
      callback: fn(msg, deliver) {
        process.send(message_subject, msg.payload)
        // Use ack_single to acknowledge each message individually
        let assert Ok(Nil) = carotte.ack_single(ch, deliver.delivery_tag)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  // Verify both messages are received
  let assert Ok(<<"message 1">>) = process.receive(message_subject, 1000)
  let assert Ok(<<"message 2">>) = process.receive(message_subject, 1000)
}

pub fn ack_multiple_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)
  let test_queue = carotte.default_queue("test_ack_multiple_queue")
  let assert Ok(_) = carotte.declare_queue(test_queue, ch)
  // Purge queue to ensure clean state
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "test_ack_multiple_queue")
  let assert Ok(_) =
    carotte.declare_exchange(carotte.exchange("test_ack_multiple_exchange"), ch)
  let assert Ok(_) =
    carotte.bind_queue(
      channel: ch,
      queue: "test_ack_multiple_queue",
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
    )

  // Publish 5 messages
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
      payload: <<"message 1">>,
      options: [],
    )
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
      payload: <<"message 2">>,
      options: [],
    )
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
      payload: <<"message 3">>,
      options: [],
    )
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
      payload: <<"message 4">>,
      options: [],
    )
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
      payload: <<"message 5">>,
      options: [],
    )

  let message_subject = process.new_subject()
  let ack_subject = process.new_subject()

  // Start the supervisor
  let consumers = process.new_name("ack_multiple_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  // Subscribe and ack only message 3 with multiple=True
  // This should acknowledge messages 1, 2, and 3
  let assert Ok(_consumer) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_ack_multiple_queue",
      callback: fn(msg, meta) {
        process.send(message_subject, msg.payload)
        case msg.payload {
          <<"message 3">> -> {
            // Acknowledge all messages up to and including message 3
            let assert Ok(Nil) = carotte.ack(ch, meta.delivery_tag, True)
            process.send(ack_subject, "acked 1-3")
            Nil
          }
          <<"message 4">> | <<"message 5">> -> {
            // Acknowledge remaining messages individually
            let assert Ok(Nil) = carotte.ack(ch, meta.delivery_tag, False)
            Nil
          }
          _ -> Nil
        }
      },
      options: [carotte.AutoAck(False)],
    )

  // Verify all messages are received
  let assert Ok(<<"message 1">>) = process.receive(message_subject, 1000)
  let assert Ok(<<"message 2">>) = process.receive(message_subject, 1000)
  let assert Ok(<<"message 3">>) = process.receive(message_subject, 1000)
  // Verify that multiple ack happened
  let assert Ok("acked 1-3") = process.receive(ack_subject, 1000)
  let assert Ok(<<"message 4">>) = process.receive(message_subject, 1000)
  let assert Ok(<<"message 5">>) = process.receive(message_subject, 1000)
}

pub fn test_unacked_then_acked() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)
  let test_queue = carotte.default_queue("test_unacked_then_acked_queue")
  let assert Ok(_) = carotte.declare_queue(test_queue, ch)
  // Purge queue to ensure clean state
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "test_unacked_then_acked_queue")

  // Publish 3 messages directly to queue
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "test_unacked_then_acked_queue",
      payload: <<"msg1">>,
      options: [],
    )
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "test_unacked_then_acked_queue",
      payload: <<"msg2">>,
      options: [],
    )
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "test_unacked_then_acked_queue",
      payload: <<"msg3">>,
      options: [],
    )

  // Start the supervisor
  let consumers = process.new_name("unacked_then_acked_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  // First consumer - receive but DON'T ack
  let received = process.new_subject()
  let assert Ok(consumer_tag) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_unacked_then_acked_queue",
      callback: fn(msg, _deliver) {
        process.send(received, msg.payload)
        // NO ACK HERE - messages should remain unacknowledged
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  // Receive all messages without acking
  let assert Ok(<<"msg1">>) = process.receive(received, 1000)
  let assert Ok(<<"msg2">>) = process.receive(received, 1000)
  let assert Ok(<<"msg3">>) = process.receive(received, 1000)

  // Unsubscribe to release unacked messages back to queue
  let assert Ok(Nil) = carotte.unsubscribe(channel: ch, consumer_tag:)
  process.sleep(100)

  // Second consumer - now ACK the messages
  let received2 = process.new_subject()
  let assert Ok(_consumer) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_unacked_then_acked_queue",
      callback: fn(msg, deliver) {
        process.send(received2, msg.payload)
        // This time ACK the messages
        let assert Ok(Nil) = carotte.ack(ch, deliver.delivery_tag, False)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  // Messages should be redelivered and then acknowledged
  let assert Ok(<<"msg1">>) = process.receive(received2, 1000)
  let assert Ok(<<"msg2">>) = process.receive(received2, 1000)
  let assert Ok(<<"msg3">>) = process.receive(received2, 1000)
}

pub fn test_redelivery_flag() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)
  let test_queue = carotte.default_queue("test_redelivery_flag_queue")
  let assert Ok(_) = carotte.declare_queue(test_queue, ch)
  // Purge queue to ensure clean state
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "test_redelivery_flag_queue")

  // Publish a message
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "test_redelivery_flag_queue",
      payload: <<"test redelivery">>,
      options: [],
    )

  // Start the supervisor
  let consumers = process.new_name("redelivery_flag_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  // First consumer - receive but don't ack
  let received = process.new_subject()
  let redelivery_flag = process.new_subject()
  let assert Ok(consumer_tag) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_redelivery_flag_queue",
      callback: fn(msg, meta) {
        process.send(received, msg.payload)
        process.send(redelivery_flag, meta.redelivered)
        // DON'T ACK - simulate consumer issue
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  // Receive the message and check it's not marked as redelivered
  let assert Ok(<<"test redelivery">>) = process.receive(received, 1000)
  let assert Ok(False) = process.receive(redelivery_flag, 1000)

  // Cancel consumer - message should be requeued
  let assert Ok(Nil) = carotte.unsubscribe(channel: ch, consumer_tag:)
  process.sleep(100)

  // Subscribe again - should get redelivered message
  let redelivered = process.new_subject()
  let redelivery_flag2 = process.new_subject()

  let assert Ok(_consumer) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_redelivery_flag_queue",
      callback: fn(msg, meta) {
        process.send(redelivered, msg.payload)
        process.send(redelivery_flag2, meta.redelivered)
        // Acknowledge this time
        let assert Ok(Nil) = carotte.ack(ch, meta.delivery_tag, False)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  // Receive the redelivered message and verify redelivered flag is True
  let assert Ok(<<"test redelivery">>) = process.receive(redelivered, 1000)
  let assert Ok(True) = process.receive(redelivery_flag2, 1000)
}

pub fn nack_with_requeue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)
  let test_queue = carotte.default_queue("test_nack_requeue_queue")
  let assert Ok(_) = carotte.declare_queue(test_queue, ch)
  // Purge queue to ensure clean state
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "test_nack_requeue_queue")

  // Publish a message
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "test_nack_requeue_queue",
      payload: <<"nack me">>,
      options: [],
    )

  // Start the supervisor
  let consumers = process.new_name("nack_requeue_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  // First consumer - receive and nack with requeue=True
  let received = process.new_subject()
  let nacked = process.new_subject()
  let assert Ok(consumer_tag) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_nack_requeue_queue",
      callback: fn(msg, meta) {
        process.send(received, msg.payload)
        // Nack with requeue - message should go back to queue
        let assert Ok(Nil) = carotte.nack(ch, meta.delivery_tag, False, True)
        process.send(nacked, "nacked")
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  // Receive the message and verify it was nacked
  let assert Ok(<<"nack me">>) = process.receive(received, 1000)
  let assert Ok("nacked") = process.receive(nacked, 1000)

  // Unsubscribe first consumer
  let assert Ok(Nil) = carotte.unsubscribe(channel: ch, consumer_tag:)
  process.sleep(100)

  // Second consumer should receive the requeued message
  let redelivered = process.new_subject()
  let assert Ok(_consumer) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_nack_requeue_queue",
      callback: fn(msg, meta) {
        process.send(redelivered, #(msg.payload, meta.redelivered))
        // Acknowledge this time
        let assert Ok(Nil) = carotte.ack(ch, meta.delivery_tag, False)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  // Verify message was redelivered
  let assert Ok(#(<<"nack me">>, True)) = process.receive(redelivered, 1000)
}

pub fn nack_single_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)
  let test_queue = carotte.default_queue("test_nack_single_queue")
  let assert Ok(_) = carotte.declare_queue(test_queue, ch)
  // Purge queue to ensure clean state
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "test_nack_single_queue")

  // Publish a message
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "test_nack_single_queue",
      payload: <<"nack single">>,
      options: [],
    )

  // Start the supervisor
  let consumers = process.new_name("nack_single_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let received = process.new_subject()
  let assert Ok(consumer_tag) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_nack_single_queue",
      callback: fn(msg, meta) {
        process.send(received, msg.payload)
        // Use nack_single convenience function with requeue
        let assert Ok(Nil) = carotte.nack_single(ch, meta.delivery_tag, True)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  let assert Ok(<<"nack single">>) = process.receive(received, 1000)

  // Unsubscribe and verify message was requeued
  let assert Ok(Nil) = carotte.unsubscribe(channel: ch, consumer_tag:)
  process.sleep(100)

  let redelivered = process.new_subject()
  let assert Ok(_) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_nack_single_queue",
      callback: fn(msg, meta) {
        process.send(redelivered, msg.payload)
        let assert Ok(Nil) = carotte.ack(ch, meta.delivery_tag, False)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  let assert Ok(<<"nack single">>) = process.receive(redelivered, 1000)
}

pub fn nack_without_requeue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)
  let test_queue = carotte.default_queue("test_nack_no_requeue_queue")
  let assert Ok(_) = carotte.declare_queue(test_queue, ch)
  // Purge queue to ensure clean state
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "test_nack_no_requeue_queue")

  // Publish a message
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "test_nack_no_requeue_queue",
      payload: <<"discard me">>,
      options: [],
    )

  // Start the supervisor
  let consumers = process.new_name("nack_no_requeue_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let received = process.new_subject()
  let assert Ok(_consumer) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_nack_no_requeue_queue",
      callback: fn(msg, meta) {
        process.send(received, msg.payload)
        // Nack without requeue - message should be discarded
        let assert Ok(Nil) = carotte.nack(ch, meta.delivery_tag, False, False)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  let assert Ok(<<"discard me">>) = process.receive(received, 1000)

  // Wait a bit and verify queue is empty (message was discarded)
  process.sleep(100)
  let assert Ok(carotte.Queue(_, 0, _)) =
    carotte.queue_status(channel: ch, queue: "test_nack_no_requeue_queue")
}

pub fn reject_with_requeue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)
  let test_queue = carotte.default_queue("test_reject_requeue_queue")
  let assert Ok(_) = carotte.declare_queue(test_queue, ch)
  // Purge queue to ensure clean state
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "test_reject_requeue_queue")

  // Publish a message
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "test_reject_requeue_queue",
      payload: <<"reject me">>,
      options: [],
    )

  // Start the supervisor
  let consumers = process.new_name("reject_requeue_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let received = process.new_subject()
  let assert Ok(consumer_tag) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_reject_requeue_queue",
      callback: fn(msg, meta) {
        process.send(received, msg.payload)
        // Reject with requeue
        let assert Ok(Nil) = carotte.reject(ch, meta.delivery_tag, True)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  let assert Ok(<<"reject me">>) = process.receive(received, 1000)

  // Unsubscribe and verify message was requeued
  let assert Ok(Nil) = carotte.unsubscribe(channel: ch, consumer_tag:)
  process.sleep(100)

  let redelivered = process.new_subject()
  let assert Ok(_) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_reject_requeue_queue",
      callback: fn(msg, meta) {
        process.send(redelivered, #(msg.payload, meta.redelivered))
        let assert Ok(Nil) = carotte.ack(ch, meta.delivery_tag, False)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  // Verify message was redelivered
  let assert Ok(#(<<"reject me">>, True)) = process.receive(redelivered, 1000)
}

pub fn reject_without_requeue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)
  let test_queue = carotte.default_queue("test_reject_no_requeue_queue")
  let assert Ok(_) = carotte.declare_queue(test_queue, ch)
  // Purge queue to ensure clean state
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "test_reject_no_requeue_queue")

  // Publish a message
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "test_reject_no_requeue_queue",
      payload: <<"reject and discard">>,
      options: [],
    )

  // Start the supervisor
  let consumers = process.new_name("reject_no_requeue_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let received = process.new_subject()
  let assert Ok(_consumer) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "test_reject_no_requeue_queue",
      callback: fn(msg, meta) {
        process.send(received, msg.payload)
        // Reject without requeue - message should be discarded
        let assert Ok(Nil) = carotte.reject(ch, meta.delivery_tag, False)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  let assert Ok(<<"reject and discard">>) = process.receive(received, 1000)

  // Wait a bit and verify queue is empty (message was discarded)
  process.sleep(100)
  let assert Ok(carotte.Queue(_, 0, _)) =
    carotte.queue_status(channel: ch, queue: "test_reject_no_requeue_queue")
}

// =============================================================================
// ERROR HANDLING TESTS
// =============================================================================

// =============================================================================
// CONNECTION ERRORS
// =============================================================================

// Test connection refused - connect to wrong port
pub fn connection_refused_test() {
  let config =
    carotte.ClientConfig(
      ..carotte.default_client(),
      port: 59_999,
      host: "127.0.0.1",
    )
  let assert Error(carotte.ConnectionRefused(_)) = carotte.start(config)
}

// Test already connected - call reconnect on connected client
pub fn already_connected_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())

  // Try to reconnect while already connected
  let assert Error(carotte.AlreadyConnected) = carotte.reconnect(client)

  // Cleanup
  let assert Ok(Nil) = carotte.close(client)
}

// =============================================================================
// CHANNEL ERRORS
// =============================================================================

// Test opening channel on closed connection
pub fn channel_connection_closed_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())

  // Close the connection
  let assert Ok(Nil) = carotte.close(client)

  // Try to open a channel on the closed connection
  let assert Error(carotte.ChannelConnectionClosed) =
    carotte.open_channel(client)
}

// =============================================================================
// EXCHANGE ERRORS
// =============================================================================

// Test binding to invalid exchange - should get ExchangeNotFound error
pub fn exchange_not_found_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create a source exchange
  let assert Ok(_) =
    carotte.declare_exchange(carotte.exchange("test_source_ex"), ch)

  // Try to bind to a non-existent destination exchange
  let assert Error(carotte.ExchangeNotFound(
    "NOT_FOUND - no exchange 'non_existent_exchange_12345' in vhost '/'",
  )) =
    carotte.bind_exchange(
      channel: ch,
      source: "test_source_ex",
      destination: "non_existent_exchange_12345",
      routing_key: "test",
    )
}

// Test exchange access refused - try to declare reserved amq.* exchange
pub fn exchange_access_refused_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Try to declare an exchange with reserved amq. prefix
  let assert Error(carotte.ExchangeAccessRefused(
    "ACCESS_REFUSED - exchange name 'amq.reserved.exchange' contains reserved prefix 'amq.*'",
  )) = carotte.declare_exchange(carotte.exchange("amq.reserved.exchange"), ch)
}

// Test exchange precondition failed - redeclare with different type
pub fn exchange_precondition_failed_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Declare a direct exchange
  let assert Ok(_) =
    carotte.declare_exchange(
      carotte.Exchange(
        ..carotte.exchange("precondition_test_ex"),
        exchange_type: carotte.Direct,
      ),
      ch,
    )

  // Need a new channel since the previous one gets closed on error
  let assert Ok(ch2) = carotte.open_channel(client)

  // Try to redeclare as fanout - should fail with precondition failed
  let assert Error(carotte.ExchangePreconditionFailed(_)) =
    carotte.declare_exchange(
      carotte.Exchange(
        ..carotte.exchange("precondition_test_ex"),
        exchange_type: carotte.Fanout,
      ),
      ch2,
    )
}

// Test exchange channel closed - operation on closed channel
pub fn exchange_channel_closed_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Close the connection (which closes all channels)
  let assert Ok(Nil) = carotte.close(client)

  // Try to declare exchange on closed channel
  let assert Error(carotte.ExchangeChannelClosed(_)) =
    carotte.declare_exchange(carotte.exchange("should_fail"), ch)
}

// Test queue operations with invalid parameters - should get QueueAccessRefused
pub fn queue_access_refused_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Try to declare a queue with invalid name (starting with amq. is reserved)
  let assert Error(carotte.QueueAccessRefused(
    "ACCESS_REFUSED - queue name 'amq.reserved.name' contains reserved prefix 'amq.*'",
  )) = carotte.declare_queue(carotte.default_queue("amq.reserved.name"), ch)
}

// Test binding queue to non-existent exchange - should get QueueNotFound
pub fn bind_to_nonexistent_exchange_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create a queue
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("test_queue_bind"), ch)

  // Try to bind to non-existent exchange
  let assert Error(carotte.QueueNotFound(
    "NOT_FOUND - no exchange 'non_existent_exchange_xyz' in vhost '/'",
  )) =
    carotte.bind_queue(
      channel: ch,
      queue: "test_queue_bind",
      exchange: "non_existent_exchange_xyz",
      routing_key: "test",
    )
}

// Test operations on closed channel - should get QueueChannelClosed
pub fn closed_channel_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Close the connection
  let assert Ok(Nil) = carotte.close(client)

  // Try to use the channel after closing - channel process no longer exists
  let assert Error(carotte.QueueChannelClosed(_)) =
    carotte.declare_queue(carotte.default_queue("test_after_close"), ch)
}

// Test deleting a queue that is in use - should get QueuePreconditionFailed
pub fn delete_queue_in_use_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create a queue
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("queue_in_use"), ch)

  // Start the supervisor
  let consumers = process.new_name("delete_queue_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  // Subscribe to the queue (puts it in use)
  let assert Ok(_consumer) =
    carotte.subscribe(
      connection,
      channel: ch,
      queue: "queue_in_use",
      callback: fn(_payload, _meta) { Nil },
    )

  // Try to delete the queue while it's in use (with if_unused: True)
  let assert Error(carotte.QueuePreconditionFailed(
    "PRECONDITION_FAILED - queue 'queue_in_use' in vhost '/' in use",
  )) =
    carotte.delete_queue(
      channel: ch,
      queue: "queue_in_use",
      if_unused: True,
      if_empty: False,
    )
}

// Test exclusive queue access - should get QueueResourceLocked
pub fn exclusive_queue_test() {
  let assert Ok(client1) = carotte.start(carotte.default_client())
  let assert Ok(ch1) = carotte.open_channel(client1)

  // Create an exclusive queue
  let assert Ok(_) =
    carotte.QueueConfig(
      ..carotte.default_queue("exclusive_test_queue"),
      exclusive: True,
    )
    |> carotte.declare_queue(ch1)

  // Try to access the same queue from another connection
  let assert Ok(client2) = carotte.start(carotte.default_client())
  let assert Ok(ch2) = carotte.open_channel(client2)

  let assert Error(carotte.QueueResourceLocked(
    "RESOURCE_LOCKED - cannot obtain exclusive access to locked queue 'exclusive_test_queue' in vhost '/'. It could be originally declared on another connection or the exclusive property value does not match that of the original declaration.",
  )) = carotte.queue_status(channel: ch2, queue: "exclusive_test_queue")
}

// =============================================================================
// PUBLISH ERRORS
// =============================================================================

// Test publish on closed channel
pub fn publish_channel_closed_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Close the connection (which closes all channels)
  let assert Ok(Nil) = carotte.close(client)

  // Try to publish on the closed channel
  let assert Error(carotte.PublishChannelClosed(_)) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "test",
      payload: <<"test message">>,
      options: [],
    )
}

// =============================================================================
// CONSUME ERRORS
// =============================================================================

// Test subscribe on closed channel - should get ConsumeInitFailed
pub fn consume_channel_closed_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create a queue first
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("consume_error_queue"), ch)

  // Close the connection
  let assert Ok(Nil) = carotte.close(client)

  // Start the supervisor
  let consumers = process.new_name("consume_error_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  // Try to subscribe on the closed channel - should fail during init
  let assert Error(_) =
    carotte.subscribe(
      connection,
      channel: ch,
      queue: "consume_error_queue",
      callback: fn(_payload, _meta) { Nil },
    )
}

// Test unsubscribe on closed channel
pub fn unsubscribe_channel_closed_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create a queue
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("unsubscribe_error_queue"), ch)

  // Start the supervisor
  let consumers = process.new_name("unsubscribe_error_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  // Subscribe
  let assert Ok(consumer_tag) =
    carotte.subscribe(
      connection,
      channel: ch,
      queue: "unsubscribe_error_queue",
      callback: fn(_payload, _meta) { Nil },
    )

  // Close the connection
  let assert Ok(Nil) = carotte.close(client)

  // Try to unsubscribe on the closed channel
  let assert Error(carotte.ConsumeChannelClosed(_)) =
    carotte.unsubscribe(channel: ch, consumer_tag:)
}

// Test ack on closed channel
pub fn ack_channel_closed_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Close the connection
  let assert Ok(Nil) = carotte.close(client)

  // Try to ack on closed channel (delivery_tag doesn't matter since channel is closed)
  let assert Error(carotte.ConsumeChannelClosed(_)) = carotte.ack(ch, 1, False)
}

// Test nack on closed channel
pub fn nack_channel_closed_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Close the connection
  let assert Ok(Nil) = carotte.close(client)

  // Try to nack on closed channel
  let assert Error(carotte.ConsumeChannelClosed(_)) =
    carotte.nack(ch, 1, False, True)
}

// Test reject on closed channel
pub fn reject_channel_closed_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Close the connection
  let assert Ok(Nil) = carotte.close(client)

  // Try to reject on closed channel
  let assert Error(carotte.ConsumeChannelClosed(_)) =
    carotte.reject(ch, 1, True)
}

// =============================================================================
// PUBLISH NO ROUTE ERROR
// =============================================================================

// Note: AMQP protocol returns "no route" errors asynchronously via basic.return.
// The publish call itself succeeds - the broker notifies about no-route via a
// callback mechanism. This library doesn't currently expose return handlers,
// so we test that a mandatory publish to an unrouted exchange still succeeds
// at the protocol level (the warning is logged by the AMQP client).
pub fn publish_no_route_async_behavior_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Declare exchange but DON'T bind any queue to it
  let assert Ok(_) =
    carotte.declare_exchange(carotte.exchange("no_route_test_exchange"), ch)

  // Publish with mandatory flag - the publish itself succeeds
  // The broker will send basic.return asynchronously (logged as warning)
  let assert Ok(Nil) =
    carotte.publish(
      channel: ch,
      exchange: "no_route_test_exchange",
      routing_key: "non.existent.route",
      payload: <<"this will trigger async return">>,
      options: [carotte.Mandatory(True)],
    )

  let assert Ok(_) = carotte.close(client)
}

// =============================================================================
// DESCRIBE ERROR FUNCTIONS
// =============================================================================

pub fn describe_connection_error_test() {
  // Test all ConnectionError variants
  assert carotte.describe_connection_error(carotte.ConnectionBlocked)
    == "Connection blocked"

  assert carotte.describe_connection_error(carotte.ConnectionClosed)
    == "Connection closed"

  assert carotte.describe_connection_error(carotte.ConnectionAuthFailure(
      "bad creds",
    ))
    == "Auth failure: bad creds"

  assert carotte.describe_connection_error(carotte.ConnectionRefused(
      "server down",
    ))
    == "Connection refused: server down"

  assert carotte.describe_connection_error(carotte.ConnectionTimeout(
      "timed out",
    ))
    == "Connection timeout: timed out"

  assert carotte.describe_connection_error(carotte.NotConnected)
    == "Not connected"

  assert carotte.describe_connection_error(carotte.AlreadyConnected)
    == "Already connected"

  assert carotte.describe_connection_error(carotte.ConnectionUnknownError(
      "mystery",
    ))
    == "Unknown error: mystery"

  // Test nested ReconnectionFailed
  assert carotte.describe_connection_error(
      carotte.ReconnectionFailed(carotte.ConnectionRefused("refused")),
    )
    == "Reconnection failed: Connection refused: refused"
}

pub fn describe_channel_error_test() {
  assert carotte.describe_channel_error(carotte.ChannelClosed("reason"))
    == "Channel closed: reason"

  assert carotte.describe_channel_error(carotte.ChannelProcessNotFound)
    == "Channel process not found"

  assert carotte.describe_channel_error(carotte.ChannelConnectionClosed)
    == "Connection closed"

  assert carotte.describe_channel_error(carotte.ChannelUnknownError("unknown"))
    == "Unknown error: unknown"
}

pub fn describe_exchange_error_test() {
  assert carotte.describe_exchange_error(carotte.ExchangeNotFound("not found"))
    == "Exchange not found: not found"

  assert carotte.describe_exchange_error(carotte.ExchangeAccessRefused(
      "refused",
    ))
    == "Access refused: refused"

  assert carotte.describe_exchange_error(carotte.ExchangePreconditionFailed(
      "failed",
    ))
    == "Precondition failed: failed"

  assert carotte.describe_exchange_error(carotte.ExchangeChannelClosed("closed"))
    == "Channel closed: closed"

  assert carotte.describe_exchange_error(carotte.ExchangeUnknownError("unknown"))
    == "Unknown error: unknown"
}

pub fn describe_queue_error_test() {
  assert carotte.describe_queue_error(carotte.QueueNotFound("not found"))
    == "Queue not found: not found"

  assert carotte.describe_queue_error(carotte.QueueAccessRefused("refused"))
    == "Access refused: refused"

  assert carotte.describe_queue_error(carotte.QueuePreconditionFailed("failed"))
    == "Precondition failed: failed"

  assert carotte.describe_queue_error(carotte.QueueResourceLocked("locked"))
    == "Resource locked: locked"

  assert carotte.describe_queue_error(carotte.QueueChannelClosed("closed"))
    == "Channel closed: closed"

  assert carotte.describe_queue_error(carotte.QueueUnknownError("unknown"))
    == "Unknown error: unknown"
}

pub fn describe_publish_error_test() {
  assert carotte.describe_publish_error(carotte.PublishNoRoute("no route"))
    == "No route: no route"

  assert carotte.describe_publish_error(carotte.PublishChannelClosed("closed"))
    == "Channel closed: closed"

  assert carotte.describe_publish_error(carotte.PublishUnknownError("unknown"))
    == "Unknown error: unknown"
}

pub fn describe_consume_error_test() {
  assert carotte.describe_consume_error(carotte.ConsumeInitTimeout)
    == "Consumer init timeout"

  assert carotte.describe_consume_error(carotte.ConsumeInitFailed("failed"))
    == "Consumer init failed: failed"

  assert carotte.describe_consume_error(carotte.ConsumeProcessNotFound)
    == "Consumer process not found"

  assert carotte.describe_consume_error(carotte.ConsumeChannelClosed("closed"))
    == "Channel closed: closed"

  assert carotte.describe_consume_error(carotte.ConsumeUnknownError("unknown"))
    == "Unknown error: unknown"
}

// =============================================================================
// QUEUE ERRORS - ADDITIONAL COVERAGE
// =============================================================================

// Test queue not found when getting status of non-existent queue
pub fn queue_not_found_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Try to get status of a queue that doesn't exist
  let assert Error(carotte.QueueNotFound(_)) =
    carotte.queue_status(
      channel: ch,
      queue: "definitely_not_existing_queue_xyz",
    )
}

// Test purge on non-existent queue
pub fn purge_nonexistent_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Try to purge a queue that doesn't exist
  let assert Error(carotte.QueueNotFound(_)) =
    carotte.purge_queue(channel: ch, queue: "nonexistent_purge_queue")
}

// Test unbind queue from non-existent exchange
// Note: RabbitMQ treats unbind as idempotent - unbinding from non-existent
// exchange silently succeeds (this is documented AMQP behavior)
pub fn unbind_queue_idempotent_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create a queue
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("unbind_idempotent_queue"), ch)

  // Unbind from non-existent exchange - should succeed (idempotent)
  let assert Ok(Nil) =
    carotte.unbind_queue(
      channel: ch,
      queue: "unbind_idempotent_queue",
      exchange: "nonexistent_exchange_for_unbind",
      routing_key: "",
    )

  let assert Ok(_) = carotte.close(client)
}

// Test delete non-empty queue with if_empty flag
pub fn delete_nonempty_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create a queue
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("nonempty_delete_queue"), ch)

  // Publish a message to it
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "nonempty_delete_queue",
      payload: <<"test message">>,
      options: [],
    )

  // Try to delete with if_empty=True - should fail
  let assert Error(carotte.QueuePreconditionFailed(_)) =
    carotte.delete_queue(
      channel: ch,
      queue: "nonempty_delete_queue",
      if_unused: False,
      if_empty: True,
    )

  // Need a new channel since precondition failure closes the channel
  let assert Ok(ch2) = carotte.open_channel(client)

  // Cleanup - delete without constraints
  let assert Ok(_) =
    carotte.delete_queue(
      channel: ch2,
      queue: "nonempty_delete_queue",
      if_unused: False,
      if_empty: False,
    )

  let assert Ok(_) = carotte.close(client)
}

// =============================================================================
// CHANNEL OPERATION TESTS
// =============================================================================

pub fn close_channel_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Close the channel explicitly
  let assert Ok(Nil) = carotte.close_channel(ch)

  // Try to use the closed channel - should fail
  let assert Error(_) = carotte.declare_queue(carotte.default_queue("test"), ch)

  let assert Ok(_) = carotte.close(client)
}

pub fn set_qos_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Set QoS with prefetch count of 10
  let assert Ok(Nil) = carotte.set_qos(ch, 10, False)

  // Create queue and test that QoS is applied
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("qos_test_queue"), ch)
  let assert Ok(_) = carotte.purge_queue(channel: ch, queue: "qos_test_queue")

  // Publish 20 messages
  let messages = list.range(1, 20)
  list.each(messages, fn(i) {
    let msg_text = "message " <> int.to_string(i)
    let payload = bit_array.from_string(msg_text)
    let assert Ok(_) =
      carotte.publish(
        channel: ch,
        exchange: "",
        routing_key: "qos_test_queue",
        payload:,
        options: [],
      )
  })

  process.sleep(100)

  // Start consumer with manual ack - only 10 messages should be delivered initially
  // due to QoS prefetch_count
  let consumers = process.new_name("qos_test_consumers")
  let assert Ok(connection) = carotte.start_consumer(consumers)

  let count_subject = process.new_subject()
  let assert Ok(_consumer) =
    carotte.subscribe_with_options(
      connection,
      channel: ch,
      queue: "qos_test_queue",
      callback: fn(_msg, _meta) {
        // Don't ack - just count
        process.send(count_subject, 1)
        Nil
      },
      options: [carotte.AutoAck(False)],
    )

  process.sleep(200)

  // Count received messages - should be approximately prefetch_count
  // (Note: exact count can vary slightly due to AMQP implementation details)
  let received_count = count_received_messages(count_subject, 0)

  // Should have received around 10 messages (allow some variance)
  assert received_count >= 10
  assert received_count <= 12

  let assert Ok(_) = carotte.close(client)
}

fn count_received_messages(subject: process.Subject(Int), count: Int) -> Int {
  case process.receive(subject, 50) {
    Ok(_) -> count_received_messages(subject, count + 1)
    Error(_) -> count
  }
}

pub fn set_qos_global_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Set QoS globally (applies to entire connection)
  let assert Ok(Nil) = carotte.set_qos(ch, 5, True)

  // Should succeed - just verify the operation works
  let assert Ok(_) = carotte.close(client)
}

pub fn transaction_commit_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create queue for testing
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("tx_commit_queue"), ch)
  let assert Ok(_) = carotte.purge_queue(channel: ch, queue: "tx_commit_queue")

  // Enable transaction mode
  let assert Ok(Nil) = carotte.start_transaction(ch)

  // Publish messages in transaction
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "tx_commit_queue",
      payload: <<"tx message 1">>,
      options: [],
    )
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "tx_commit_queue",
      payload: <<"tx message 2">>,
      options: [],
    )

  // Messages should not be visible yet
  process.sleep(100)
  let assert Ok(carotte.Queue(_, 0, _)) =
    carotte.queue_status(channel: ch, queue: "tx_commit_queue")

  // Commit the transaction
  let assert Ok(Nil) = carotte.commit_transaction(ch)

  // Now messages should be visible
  process.sleep(100)
  let assert Ok(carotte.Queue(_, 2, _)) =
    carotte.queue_status(channel: ch, queue: "tx_commit_queue")

  let assert Ok(_) = carotte.close(client)
}

pub fn transaction_rollback_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create queue for testing
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("tx_rollback_queue"), ch)
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "tx_rollback_queue")

  // Enable transaction mode
  let assert Ok(Nil) = carotte.start_transaction(ch)

  // Publish messages in transaction
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "tx_rollback_queue",
      payload: <<"rollback message 1">>,
      options: [],
    )
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "tx_rollback_queue",
      payload: <<"rollback message 2">>,
      options: [],
    )

  // Rollback the transaction
  let assert Ok(Nil) = carotte.rollback_transaction(ch)

  // Messages should not be in the queue
  process.sleep(100)
  let assert Ok(carotte.Queue(_, 0, _)) =
    carotte.queue_status(channel: ch, queue: "tx_rollback_queue")

  let assert Ok(_) = carotte.close(client)
}

pub fn transaction_multiple_commits_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create queue for testing
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("tx_multiple_queue"), ch)
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "tx_multiple_queue")

  // Enable transaction mode
  let assert Ok(Nil) = carotte.start_transaction(ch)

  // First batch
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "tx_multiple_queue",
      payload: <<"batch 1">>,
      options: [],
    )
  let assert Ok(Nil) = carotte.commit_transaction(ch)

  process.sleep(100)
  let assert Ok(carotte.Queue(_, 1, _)) =
    carotte.queue_status(channel: ch, queue: "tx_multiple_queue")

  // Second batch
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "tx_multiple_queue",
      payload: <<"batch 2">>,
      options: [],
    )
  let assert Ok(Nil) = carotte.commit_transaction(ch)

  process.sleep(100)
  let assert Ok(carotte.Queue(_, 2, _)) =
    carotte.queue_status(channel: ch, queue: "tx_multiple_queue")

  let assert Ok(_) = carotte.close(client)
}

// =============================================================================
// GET MESSAGE (SYNCHRONOUS POLL) TESTS
// =============================================================================

pub fn get_message_with_auto_ack_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create queue
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("get_message_queue"), ch)
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "get_message_queue")

  // Initially queue is empty
  let assert Ok(option.None) =
    carotte.get_message(ch, queue: "get_message_queue", auto_ack: True)

  // Publish a message
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "get_message_queue",
      payload: <<"get this message">>,
      options: [],
    )

  process.sleep(50)

  // Get the message
  let assert Ok(option.Some(#(payload, deliver))) =
    carotte.get_message(ch, queue: "get_message_queue", auto_ack: True)

  // First check if deliver was decoded correctly
  assert deliver.routing_key == "get_message_queue"
  assert deliver.consumer_tag == ""
  assert deliver.redelivered == False

  // Now check payload
  assert payload.payload == <<"get this message">>

  // Message should be auto-acked, so queue is empty
  process.sleep(50)
  let assert Ok(carotte.Queue(_, 0, _)) =
    carotte.queue_status(channel: ch, queue: "get_message_queue")

  let assert Ok(_) = carotte.close(client)
}

pub fn get_message_with_manual_ack_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create queue
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("get_manual_ack_queue"), ch)
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "get_manual_ack_queue")

  // Publish a message
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "get_manual_ack_queue",
      payload: <<"manual ack get">>,
      options: [],
    )

  process.sleep(50)

  // Get the message without auto-ack
  let assert Ok(option.Some(#(payload, deliver))) =
    carotte.get_message(ch, queue: "get_manual_ack_queue", auto_ack: False)

  assert payload.payload == <<"manual ack get">>

  // Message is not acked yet - should still be unacknowledged
  // (Note: unacked messages don't show in message_count but are in flight)

  // Manually acknowledge the message
  let assert Ok(Nil) = carotte.ack(ch, deliver.delivery_tag, False)

  process.sleep(50)

  // Queue should be empty now
  let assert Ok(carotte.Queue(_, 0, _)) =
    carotte.queue_status(channel: ch, queue: "get_manual_ack_queue")

  let assert Ok(_) = carotte.close(client)
}

pub fn get_message_empty_queue_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create empty queue
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("empty_get_queue"), ch)
  let assert Ok(_) = carotte.purge_queue(channel: ch, queue: "empty_get_queue")

  // Try to get message from empty queue
  let assert Ok(option.None) =
    carotte.get_message(ch, queue: "empty_get_queue", auto_ack: True)

  let assert Ok(_) = carotte.close(client)
}

pub fn get_message_multiple_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create queue
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("get_multiple_queue"), ch)
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "get_multiple_queue")

  // Publish multiple messages
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "get_multiple_queue",
      payload: <<"message 1">>,
      options: [],
    )
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "get_multiple_queue",
      payload: <<"message 2">>,
      options: [],
    )
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "get_multiple_queue",
      payload: <<"message 3">>,
      options: [],
    )

  process.sleep(50)

  // Get messages one by one
  let assert Ok(option.Some(#(msg1, _))) =
    carotte.get_message(ch, queue: "get_multiple_queue", auto_ack: True)
  assert msg1.payload == <<"message 1">>

  let assert Ok(option.Some(#(msg2, _))) =
    carotte.get_message(ch, queue: "get_multiple_queue", auto_ack: True)
  assert msg2.payload == <<"message 2">>

  let assert Ok(option.Some(#(msg3, _))) =
    carotte.get_message(ch, queue: "get_multiple_queue", auto_ack: True)
  assert msg3.payload == <<"message 3">>

  // Queue should be empty now
  let assert Ok(option.None) =
    carotte.get_message(ch, queue: "get_multiple_queue", auto_ack: True)

  let assert Ok(_) = carotte.close(client)
}

pub fn get_message_basic_payload_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create queue
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("get_basic_payload_queue"), ch)
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "get_basic_payload_queue")

  // Publish simple message
  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "get_basic_payload_queue",
      payload: <<"simple message">>,
      options: [],
    )

  process.sleep(50)

  // Get the message and verify payload
  let assert Ok(option.Some(#(payload, _deliver))) =
    carotte.get_message(ch, queue: "get_basic_payload_queue", auto_ack: True)

  // Verify the basic payload works
  assert payload.payload == <<"simple message">>

  let assert Ok(_) = carotte.close(client)
}

pub fn get_message_with_properties_and_headers_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create queue
  let assert Ok(_) =
    carotte.declare_queue(carotte.default_queue("get_props_headers_queue"), ch)
  let assert Ok(_) =
    carotte.purge_queue(channel: ch, queue: "get_props_headers_queue")

  // Publish message with properties and headers
  let headers =
    carotte.headers_from_list([
      #("test_key", carotte.StringHeader("test_value")),
      #("int_key", carotte.IntHeader(123)),
    ])

  let assert Ok(_) =
    carotte.publish(
      channel: ch,
      exchange: "",
      routing_key: "get_props_headers_queue",
      payload: <<"message with props">>,
      options: [
        carotte.ContentType("text/plain"),
        carotte.MessageHeaders(headers),
        carotte.CorrelationId("corr-123"),
        carotte.Priority(5),
      ],
    )

  process.sleep(50)

  // Get the message and verify properties and headers
  let assert Ok(option.Some(#(payload, _deliver))) =
    carotte.get_message(ch, queue: "get_props_headers_queue", auto_ack: True)

  // Verify the payload
  assert payload.payload == <<"message with props">>

  // Verify properties
  let assert Ok(carotte.ContentType("text/plain")) =
    list.find(payload.properties, fn(prop) {
      case prop {
        carotte.ContentType(_) -> True
        _ -> False
      }
    })

  let assert Ok(carotte.CorrelationId("corr-123")) =
    list.find(payload.properties, fn(prop) {
      case prop {
        carotte.CorrelationId(_) -> True
        _ -> False
      }
    })

  let assert Ok(carotte.Priority(5)) =
    list.find(payload.properties, fn(prop) {
      case prop {
        carotte.Priority(_) -> True
        _ -> False
      }
    })

  // Verify headers
  let received_headers = carotte.headers_to_list(payload.headers)
  assert list.length(received_headers) == 2

  let assert Ok(#(_, carotte.StringHeader("test_value"))) =
    list.find(received_headers, fn(h) { h.0 == "test_key" })

  let assert Ok(#(_, carotte.IntHeader(123))) =
    list.find(received_headers, fn(h) { h.0 == "int_key" })

  let assert Ok(_) = carotte.close(client)
}
