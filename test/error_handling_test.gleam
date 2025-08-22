import carotte
import carotte/channel
import carotte/exchange
import carotte/queue
import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import gleeunit/should

// Test that we get AlreadyRegistered error when trying to use same name twice
pub fn already_registered_error_test() {
  let process_name = process.new_name("already_registered_test")

  // First client should succeed
  let assert Ok(_client1) = carotte.start(carotte.default_client(process_name))

  // Second client with same name should fail
  let result = carotte.start(carotte.default_client(process_name))

  case result {
    Error(carotte.AlreadyRegistered(msg)) -> {
      let assert "Process name already registered" = msg
    }
    _ -> panic as "Expected AlreadyRegistered error"
  }
}

// Test binding to invalid exchange - should get NotFound error
pub fn exchange_not_found_test() {
  let process_name = process.new_name("exchange_not_found_test")
  let assert Ok(client) = carotte.start(carotte.default_client(process_name))
  let assert Ok(ch) = channel.open_channel(client)

  // Create a source exchange
  let assert Ok(_) = exchange.declare(exchange.new("test_source_ex"), ch)

  // Try to bind to a non-existent destination exchange
  let result =
    exchange.bind(
      channel: ch,
      source: "test_source_ex",
      destination: "non_existent_exchange_12345",
      routing_key: "test",
    )

  // Should get NotFound error
  case result {
    Error(carotte.NotFound(message)) -> {
      let assert "NOT_FOUND - no exchange 'non_existent_exchange_12345' in vhost '/'" =
        message
    }
    Error(_) -> {
      panic as "Expected NotFound error"
    }
    Ok(_) -> panic as "Expected error when binding to non-existent exchange"
  }
}

// Test queue operations with invalid parameters - should get AccessRefused
pub fn queue_access_refused_test() {
  let process_name = process.new_name("queue_access_refused_test")
  let assert Ok(client) = carotte.start(carotte.default_client(process_name))
  let assert Ok(ch) = channel.open_channel(client)

  // Try to declare a queue with invalid name (starting with amq. is reserved)
  let result = queue.declare(queue.new("amq.reserved.name"), ch)

  case result {
    Error(carotte.AccessRefused(msg)) -> {
      let assert "ACCESS_REFUSED - queue name 'amq.reserved.name' contains reserved prefix 'amq.*'" =
        msg
    }
    Error(_) -> {
      panic as "Expected AccessRefused error"
    }
    Ok(_) -> panic as "Expected error when declaring reserved queue name"
  }
}

// Test binding queue to non-existent exchange - should get NotFound
pub fn bind_to_nonexistent_exchange_test() {
  let process_name = process.new_name("bind_nonexistent_test")
  let assert Ok(client) = carotte.start(carotte.default_client(process_name))
  let assert Ok(ch) = channel.open_channel(client)

  // Create a queue
  let assert Ok(_) = queue.declare(queue.new("test_queue_bind"), ch)

  // Try to bind to non-existent exchange
  let result =
    queue.bind(
      channel: ch,
      queue: "test_queue_bind",
      exchange: "non_existent_exchange_xyz",
      routing_key: "test",
    )

  case result {
    Error(carotte.NotFound(msg)) -> {
      let assert "NOT_FOUND - no exchange 'non_existent_exchange_xyz' in vhost '/'" =
        msg
    }
    Error(other) -> {
      io.println("Got unexpected error type: " <> error_to_string(other))
      panic as "Expected NotFound error"
    }
    Ok(_) -> panic as "Expected error when binding to non-existent exchange"
  }
}

// Test operations on closed channel - should get ProcessNotFound or Closed
pub fn closed_channel_test() {
  let process_name = process.new_name("closed_channel_test")
  let assert Ok(client) = carotte.start(carotte.default_client(process_name))
  let assert Ok(ch) = channel.open_channel(client)

  // Close the connection
  let _ = carotte.close(client)

  // Try to use the channel after closing
  let result = queue.declare(queue.new("test_after_close"), ch)

  case result {
    Error(carotte.ProcessNotFound) -> {
      Nil
    }
    Error(carotte.Closed) -> {
      Nil
    }
    Error(_) -> {
      panic as "Expected ProcessNotFound or Closed error"
    }
    Ok(_) -> panic as "Expected error when using closed channel"
  }
}

// Test deleting a queue that is in use - should get PreconditionFailed
pub fn delete_queue_in_use_test() {
  let process_name = process.new_name("delete_queue_in_use_test")
  let assert Ok(client) = carotte.start(carotte.default_client(process_name))
  let assert Ok(ch) = channel.open_channel(client)

  // Create a queue
  let assert Ok(_) = queue.declare(queue.new("queue_in_use"), ch)

  // Subscribe to the queue (puts it in use)
  let assert Ok(_consumer_tag) =
    queue.subscribe(
      channel: ch,
      queue: "queue_in_use",
      callback: fn(_payload, _meta) { Nil },
    )

  // Try to delete the queue while it's in use (with if_unused: True)
  let result = queue.delete(ch, "queue_in_use", True, False)

  case result {
    Error(carotte.PreconditionFailed(msg)) -> {
      let assert "PRECONDITION_FAILED - queue 'queue_in_use' in vhost '/' in use" =
        msg
    }
    Error(_) -> {
      panic as "Expected PreconditionFailed error"
    }
    Ok(_) -> panic as "Expected error when deleting queue in use"
  }
}

// Test exclusive queue access - should get ResourceLocked
pub fn exclusive_queue_test() {
  let process_name1 = process.new_name("exclusive_queue_test1")
  let process_name2 = process.new_name("exclusive_queue_test2")

  let assert Ok(client1) = carotte.start(carotte.default_client(process_name1))
  let assert Ok(ch1) = channel.open_channel(client1)

  // Create an exclusive queue
  let assert Ok(_) =
    queue.new("exclusive_test_queue")
    |> queue.as_exclusive()
    |> queue.declare(ch1)

  // Try to access the same queue from another connection
  let assert Ok(client2) = carotte.start(carotte.default_client(process_name2))
  let assert Ok(ch2) = channel.open_channel(client2)

  let result = queue.status(ch2, "exclusive_test_queue")

  case result {
    Error(carotte.ResourceLocked(msg)) -> {
      let assert "RESOURCE_LOCKED - cannot obtain exclusive access to locked queue 'exclusive_test_queue' in vhost '/'. It could be originally declared on another connection or the exclusive property value does not match that of the original declaration." =
        msg
    }
    Error(_) -> {
      panic as "Expected ResourceLocked error"
    }
    Ok(_) ->
      panic as "Expected error when accessing exclusive queue from different connection"
  }
}

// Helper function to convert error to string for debugging
fn error_to_string(error: carotte.CarotteError) -> String {
  case error {
    carotte.Blocked -> "Blocked"
    carotte.Closed -> "Closed"
    carotte.AuthFailure(msg) -> "AuthFailure: " <> msg
    carotte.ProcessNotFound -> "ProcessNotFound"
    carotte.AlreadyRegistered(msg) -> "AlreadyRegistered: " <> msg
    carotte.NotFound(msg) -> "NotFound: " <> msg
    carotte.AccessRefused(msg) -> "AccessRefused: " <> msg
    carotte.PreconditionFailed(msg) -> "PreconditionFailed: " <> msg
    carotte.ResourceLocked(msg) -> "ResourceLocked: " <> msg
    carotte.ChannelClosed(msg) -> "ChannelClosed: " <> msg
    carotte.ConnectionRefused(msg) -> "ConnectionRefused: " <> msg
    carotte.ConnectionTimeout(msg) -> "ConnectionTimeout: " <> msg
    carotte.FrameError(msg) -> "FrameError: " <> msg
    carotte.InternalError(msg) -> "InternalError: " <> msg
    carotte.InvalidPath(msg) -> "InvalidPath: " <> msg
    carotte.NoRoute(msg) -> "NoRoute: " <> msg
    carotte.NotAllowed(msg) -> "NotAllowed: " <> msg
    carotte.NotImplemented(msg) -> "NotImplemented: " <> msg
    carotte.UnexpectedFrame(msg) -> "UnexpectedFrame: " <> msg
    carotte.CommandInvalid(msg) -> "CommandInvalid: " <> msg
    carotte.UnknownError(msg) -> "UnknownError: " <> msg
  }
}
