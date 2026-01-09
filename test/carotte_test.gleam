import carotte
import gleam/erlang/process
import gleam/list
import gleam/otp/static_supervisor
import gleam/string
import gleeunit

pub fn main() {
  gleeunit.main()
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
    == carotte.declare_queue(carotte.queue("declare_queue"), channel)
}

pub fn declare_queue_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  assert Ok(Nil)
    == carotte.declare_queue_async(
      carotte.queue("declare_queue_async"),
      channel,
    )
}

pub fn delete_queue_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  let assert Ok(_) =
    carotte.declare_queue(carotte.queue("delete_queue"), channel)

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

  let assert Ok(_) = carotte.declare_queue(carotte.queue("bind_queue"), channel)

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
    carotte.declare_queue(carotte.queue("unbind_queue"), channel)
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
    carotte.declare_queue(carotte.queue("purge_queue"), channel)

  assert Ok(0) == carotte.purge_queue(channel:, queue: "purge_queue")
}

pub fn purge_queue_async_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(_) =
    carotte.declare_queue(carotte.queue("purge_queue_async"), channel)

  assert Ok(Nil)
    == carotte.purge_queue_async(channel:, queue: "purge_queue_async")
}

pub fn queue_status_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(_) =
    carotte.declare_queue(carotte.queue("queue_status"), channel)

  assert Ok(carotte.Queue("queue_status", 0, 0))
    == carotte.queue_status(channel:, queue: "queue_status")
}

pub fn publish_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(Nil) =
    carotte.declare_exchange(carotte.exchange("p_exchange"), channel)
  let assert Ok(_) = carotte.declare_queue(carotte.queue("p_queue"), channel)

  assert Ok(Nil)
    == carotte.publish(
      channel: channel,
      exchange: "p_exchange",
      routing_key: "",
      payload: "test",
      options: [],
    )
}

pub fn publish_with_options_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(Nil) =
    carotte.declare_exchange(carotte.exchange("pwo_exchange"), channel)
  let assert Ok(_) = carotte.declare_queue(carotte.queue("pwo_queue"), channel)
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
      payload: "publish with options",
      options: [
        carotte.Mandatory(True),
        carotte.ContentType("text/plain"),
        carotte.ContentEncoding("utf-8"),
        carotte.MessageHeaders(headers),
        carotte.Persistent(True),
        carotte.CorrelationId("123"),
        carotte.Priority(9),
        carotte.Expiration("1000"),
        carotte.MessageId("123"),
        carotte.Timestamp(123),
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
    carotte.declare_queue(carotte.queue("consume_queue"), channel)
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
      payload: "payload1",
      options: [],
    )
  let assert Ok(_) =
    carotte.publish(
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
  let assert Ok(channel) = carotte.open_channel(client)
  let assert Ok(Nil) =
    carotte.declare_exchange(carotte.exchange("unsubscribe_exchange"), channel)
  let assert Ok(_) =
    carotte.declare_queue(carotte.queue("unsubscribe_queue"), channel)
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
      payload: "payload",
      options: [
        carotte.Mandatory(True),
        carotte.ContentType("text/plain"),
        carotte.ContentEncoding("utf-8"),
        carotte.Persistent(True),
        carotte.CorrelationId("123"),
        carotte.Priority(9),
        carotte.Expiration("1000"),
        carotte.MessageId("123"),
        carotte.Timestamp(123),
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
    carotte.declare_queue(carotte.queue("headers_test_queue"), channel)
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
      payload: "test payload",
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

pub fn declare_queue_with_auto_generated_name_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(channel) = carotte.open_channel(client)

  // Declare a queue with an empty name - RabbitMQ should generate one
  let assert Ok(carotte.Queue(name:, message_count: 0, consumer_count: 0)) =
    carotte.QueueConfig(..carotte.queue(""), exclusive: True, auto_delete: True)
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
    carotte.declare_queue(carotte.queue("supervised_test_queue"), channel)
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
      payload: "Hello from supervised test!",
      options: [],
    )

  // 10. Verify the message was received
  let assert Ok("Hello from supervised test!") =
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
  let assert Ok(_) = carotte.declare_queue(carotte.queue(queue1), channel)
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
  let assert Ok(_) = carotte.declare_queue(carotte.queue(queue2), channel)
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
        process.send(subject1, "q1:" <> payload.payload)
      },
    )

  // 6. Dynamically add second consumer to queue 2
  let assert Ok(consumer_tag2) =
    carotte.subscribe(
      connection,
      channel:,
      queue: queue2,
      callback: fn(payload, _) {
        process.send(subject2, "q2:" <> payload.payload)
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
      payload: "msg1",
      options: [],
    )
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: exchange2,
      routing_key: "",
      payload: "msg2",
      options: [],
    )

  // 8. Verify both consumers received their messages
  let assert Ok("q1:msg1") = process.receive(subject1, 2000)
  let assert Ok("q2:msg2") = process.receive(subject2, 2000)

  // 9. Unsubscribe the first consumer while keeping the second active
  let assert Ok(_) = carotte.unsubscribe(channel:, consumer_tag: consumer_tag1)
  process.sleep(100)

  // 10. Publish another message to queue 2 - should still work
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: exchange2,
      routing_key: "",
      payload: "msg3",
      options: [],
    )

  // 11. Verify second consumer still receives messages
  let assert Ok("q2:msg3") = process.receive(subject2, 2000)

  // 12. Add a third consumer to queue 1 (demonstrating dynamic addition)
  let subject3 = process.new_subject()
  let assert Ok(consumer_tag3) =
    carotte.subscribe(
      connection,
      channel:,
      queue: queue1,
      callback: fn(payload, _) {
        process.send(subject3, "q1_new:" <> payload.payload)
      },
    )
  process.sleep(100)

  // 13. Publish to queue 1 again - new consumer should receive it
  let assert Ok(_) =
    carotte.publish(
      channel:,
      exchange: exchange1,
      routing_key: "",
      payload: "msg4",
      options: [],
    )

  let assert Ok("q1_new:msg4") = process.receive(subject3, 2000)

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
  let assert Ok(_) = carotte.declare_queue(carotte.queue(queue), channel)
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
      payload: "manual_ack_msg",
      options: [],
    )

  // 7. Verify message was received and acked
  let assert Ok("manual_ack_msg") = process.receive(received, 2000)

  // 8. Verify queue is empty (message was acked)
  process.sleep(100)
  let assert Ok(carotte.Queue(_, 0, _)) = carotte.queue_status(channel:, queue:)

  // 9. Cleanup
  let assert Ok(_) = carotte.close(client)
}
