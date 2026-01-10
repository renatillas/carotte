import carotte
import gleam/erlang/process

pub fn manual_ack_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)
  let test_queue = carotte.queue("test_ack_queue")
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
  let test_queue = carotte.queue("test_ack_single_queue")
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
  let test_queue = carotte.queue("test_ack_multiple_queue")
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
  let test_queue = carotte.queue("test_unacked_then_acked_queue")
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
  let test_queue = carotte.queue("test_redelivery_flag_queue")
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
  let test_queue = carotte.queue("test_nack_requeue_queue")
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
  let test_queue = carotte.queue("test_nack_single_queue")
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
  let test_queue = carotte.queue("test_nack_no_requeue_queue")
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
  let test_queue = carotte.queue("test_reject_requeue_queue")
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
  let test_queue = carotte.queue("test_reject_no_requeue_queue")
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
