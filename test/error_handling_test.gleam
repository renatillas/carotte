import carotte

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
  let assert Ok(sup) = carotte.consumer_start(intensity: 1, period: 1)

  // Subscribe to the queue (puts it in use)
  let assert Ok(_consumer) =
    carotte.subscribe(
      sup.data,
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
