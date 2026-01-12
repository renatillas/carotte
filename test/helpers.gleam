import carotte
import gleam/erlang/process

/// Setup a test client with automatic cleanup.
/// Use with the `use` keyword for automatic connection closing.
///
/// ## Example
/// ```gleam
/// pub fn my_test() {
///   use client <- with_client()
///   // Use client...
///   // Automatically closed when callback returns
/// }
/// ```
pub fn with_client(callback: fn(carotte.Client) -> a) -> a {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let result = callback(client)
  // Best-effort cleanup - ignore errors (connection might already be closed)
  let _ = carotte.close(client)
  result
}

/// Setup a test client and channel with automatic cleanup.
/// Closes both channel and client when the callback completes.
///
/// ## Example
/// ```gleam
/// pub fn my_test() {
///   use #(client, ch) <- with_channel()
///   // Use client and channel...
///   // Automatically cleaned up
/// }
/// ```
pub fn with_channel(callback: fn(#(carotte.Client, carotte.Channel)) -> a) -> a {
  use client <- with_client()
  let assert Ok(ch) = carotte.open_channel(client)
  let result = callback(#(client, ch))
  let _ = carotte.close_channel(ch)
  result
}

/// Setup a test queue with automatic cleanup (purge and delete).
/// Creates the queue, purges it to ensure clean state, runs the callback,
/// then purges and deletes it.
///
/// ## Example
/// ```gleam
/// pub fn my_test() {
///   use #(client, ch) <- with_channel()
///   use queue <- with_queue(ch, "test_queue")
///   // Queue is empty and ready to use
///   // Automatically purged and deleted after test
/// }
/// ```
pub fn with_queue(
  ch: carotte.Channel,
  name: String,
  callback: fn(carotte.Queue) -> a,
) -> a {
  let assert Ok(queue) = carotte.declare_queue(carotte.default_queue(name), ch)
  // Purge before test to ensure clean state
  let _ = carotte.purge_queue(channel: ch, queue: name)
  let result = callback(queue)
  // Cleanup: purge and delete
  let _ = carotte.purge_queue(channel: ch, queue: name)
  let _ =
    carotte.delete_queue(
      channel: ch,
      queue: name,
      if_unused: False,
      if_empty: False,
    )
  result
}

/// Setup a test exchange with automatic cleanup (delete).
/// Creates the exchange, runs the callback, then deletes it.
///
/// ## Example
/// ```gleam
/// pub fn my_test() {
///   use #(client, ch) <- with_channel()
///   use _exchange <- with_exchange(ch, "test_exchange")
///   // Use exchange...
///   // Automatically deleted
/// }
/// ```
pub fn with_exchange(
  ch: carotte.Channel,
  name: String,
  callback: fn(Nil) -> a,
) -> a {
  let assert Ok(_) = carotte.declare_exchange(carotte.exchange(name), ch)
  let result = callback(Nil)
  // Cleanup: delete exchange
  let _ = carotte.delete_exchange(channel: ch, exchange: name, if_unused: False)
  result
}

/// Setup a complete test environment with client, channel, exchange, and queue.
/// All resources are automatically cleaned up when the callback completes.
///
/// ## Example
/// ```gleam
/// pub fn my_test() {
///   use #(client, ch, queue) <- with_setup("test_exchange", "test_queue")
///   // Bind queue to exchange
///   let assert Ok(_) = carotte.bind_queue(
///     channel: ch,
///     queue: "test_queue",
///     exchange: "test_exchange",
///     routing_key: "",
///   )
///   // Test...
///   // Everything automatically cleaned up
/// }
/// ```
pub fn with_setup(
  exchange_name: String,
  queue_name: String,
  callback: fn(#(carotte.Client, carotte.Channel, carotte.Queue)) -> a,
) -> a {
  use #(client, ch) <- with_channel()
  use _exchange <- with_exchange(ch, exchange_name)
  use queue <- with_queue(ch, queue_name)
  callback(#(client, ch, queue))
}

/// Setup a consumer supervisor with automatic cleanup.
/// Note: Consumer cleanup happens automatically when the connection closes.
///
/// ## Example
/// ```gleam
/// pub fn my_test() {
///   use #(client, ch) <- with_channel()
///   use consumer <- with_consumer()
///   // Subscribe to queues...
///   // Automatically cleaned up
/// }
/// ```
pub fn with_consumer(callback: fn(carotte.Consumer) -> a) -> a {
  let name = process.new_name("test_consumers")
  let assert Ok(consumer) = carotte.start_consumer(name)
  callback(consumer)
}
