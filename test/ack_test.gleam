import carotte
import carotte/channel
import carotte/exchange
import carotte/publisher
import carotte/queue
import gleam/erlang/process

pub fn manual_ack_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = channel.open_channel(client)
  let test_queue = queue.new("test_ack_queue")
  let assert Ok(_) = queue.declare(test_queue, ch)
  let assert Ok(_) = exchange.declare(exchange.new("test_ack_exchange"), ch)
  let assert Ok(Nil) =
    queue.bind(
      channel: ch,
      queue: "test_ack_queue",
      exchange: "test_ack_exchange",
      routing_key: "",
    )
  let assert Ok(Nil) =
    publisher.publish(
      channel: ch,
      exchange: "test_ack_exchange",
      routing_key: "",
      payload: "test message for ack",
      options: [],
    )

  let assert Ok(_consumer_tag) =
    queue.subscribe(
      channel: ch,
      queue: "test_ack_queue",
      callback: fn(msg, deliver) {
        assert msg.payload == "test message for ack"
        let _ = queue.ack(ch, deliver.delivery_tag, False)
        Nil
      },
    )
  process.sleep(1000)

  let assert Ok(_) =
    queue.delete(
      channel: ch,
      queue: "test_ack_queue",
      if_unused: False,
      if_empty: False,
    )
}

pub fn ack_single_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = channel.open_channel(client)
  let test_queue = queue.new("test_ack_single_queue")
  let assert Ok(_) = queue.declare(test_queue, ch)
  let assert Ok(_) =
    exchange.declare(exchange.new("test_ack_single_exchange"), ch)
  let assert Ok(_) =
    queue.bind(
      channel: ch,
      queue: "test_ack_single_queue",
      exchange: "test_ack_single_exchange",
      routing_key: "",
    )

  assert Ok(Nil)
    == publisher.publish(
      channel: ch,
      exchange: "test_ack_single_exchange",
      routing_key: "",
      payload: "message 1",
      options: [],
    )
  assert Ok(Nil)
    == publisher.publish(
      channel: ch,
      exchange: "test_ack_single_exchange",
      routing_key: "",
      payload: "message 2",
      options: [],
    )

  // Then subscribe to the queue
  let assert Ok(_consumer_tag) =
    queue.subscribe(
      channel: ch,
      queue: "test_ack_single_queue",
      callback: fn(msg, meta) {
        // Assert we got message 1 and use ack_single to acknowledge it
        assert msg.payload == "message 1" || msg.payload == "message 2"
        let _ = queue.ack_single(ch, meta.delivery_tag)
        Nil
      },
    )

  process.sleep(1000)
  let assert Ok(_) =
    queue.delete(
      channel: ch,
      queue: "test_ack_single_queue",
      if_unused: False,
      if_empty: False,
    )
}

pub fn ack_multiple_test() {
  let assert Ok(client) = carotte.start(carotte.default_client())
  let assert Ok(ch) = channel.open_channel(client)
  let test_queue = queue.new("test_ack_multiple_queue")
  let assert Ok(_) = queue.declare(test_queue, ch)
  let assert Ok(_) =
    exchange.declare(exchange.new("test_ack_multiple_exchange"), ch)
  let assert Ok(_) =
    queue.bind(
      channel: ch,
      queue: "test_ack_multiple_queue",
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
    )

  // Publish multiple test messages first
  let assert Ok(_) =
    publisher.publish(
      channel: ch,
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
      payload: "message A",
      options: [],
    )
  let assert Ok(_) =
    publisher.publish(
      channel: ch,
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
      payload: "message B",
      options: [],
    )
  let assert Ok(_) =
    publisher.publish(
      channel: ch,
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
      payload: "message C",
      options: [],
    )

  // Then subscribe to the queue
  let assert Ok(_consumer_tag) =
    queue.subscribe(
      channel: ch,
      queue: "test_ack_multiple_queue",
      callback: fn(msg, meta) {
        assert msg.payload == "message A"
          || msg.payload == "message B"
          || msg.payload == "message C"
        case msg.payload {
          "message C" -> {
            let assert Ok(_) = queue.ack(ch, meta.delivery_tag, True)
            Nil
          }
          _ -> Nil
        }
        Nil
      },
    )

  process.sleep(1000)
  let assert Ok(_) =
    queue.delete(
      channel: ch,
      queue: "test_ack_multiple_queue",
      if_unused: False,
      if_empty: False,
    )
}
