import carotte
import gleam/erlang/process

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
  )) = carotte.declare_queue(carotte.queue("amq.reserved.name"), ch)
}

// Test binding queue to non-existent exchange - should get QueueNotFound
pub fn bind_to_nonexistent_exchange_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create a queue
  let assert Ok(_) = carotte.declare_queue(carotte.queue("test_queue_bind"), ch)

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
    carotte.declare_queue(carotte.queue("test_after_close"), ch)
}

// Test deleting a queue that is in use - should get QueuePreconditionFailed
pub fn delete_queue_in_use_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = carotte.open_channel(client)

  // Create a queue
  let assert Ok(_) = carotte.declare_queue(carotte.queue("queue_in_use"), ch)

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
      ..carotte.queue("exclusive_test_queue"),
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
      payload: "test message",
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
    carotte.declare_queue(carotte.queue("consume_error_queue"), ch)

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
    carotte.declare_queue(carotte.queue("unsubscribe_error_queue"), ch)

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
