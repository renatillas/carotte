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
  let message_subject = process.new_subject()

  let assert Ok(_consumer_tag) =
    queue.subscribe_with_options(
      channel: ch,
      queue: "test_ack_queue",
      callback: fn(msg, deliver) {
        process.send(message_subject, msg.payload)
        let _ = queue.ack(ch, deliver.delivery_tag, False)
        Nil
      },
      options: [queue.RequiredAck(True)],
    )
  process.sleep(1000)
  let assert Ok("test message for ack") = process.receive(message_subject, 1000)
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
  let message_subject = process.new_subject()
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
    queue.subscribe_with_options(
      channel: ch,
      queue: "test_ack_single_queue",
      callback: fn(msg, deliver) {
        // Assert we got message 1 and use ack_single to acknowledge it
        process.send(message_subject, msg.payload)
        let _ = queue.ack_single(ch, deliver.delivery_tag)
        Nil
      },
      options: [queue.RequiredAck(True)],
    )

  process.sleep(1000)
  let assert Ok("message 1") = process.receive(message_subject, 1000)
  let assert Ok("message 2") = process.receive(message_subject, 1000)
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
  let assert Ok(Nil) =
    publisher.publish(
      channel: ch,
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
      payload: "message A",
      options: [],
    )
  let assert Ok(Nil) =
    publisher.publish(
      channel: ch,
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
      payload: "message B",
      options: [],
    )
  let assert Ok(Nil) =
    publisher.publish(
      channel: ch,
      exchange: "test_ack_multiple_exchange",
      routing_key: "",
      payload: "message C",
      options: [],
    )
  let message_subject = process.new_subject()

  let assert Ok(_consumer_tag) =
    queue.subscribe(
      channel: ch,
      queue: "test_ack_multiple_queue",
      callback: fn(msg, meta) {
        process.send(message_subject, msg.payload)
        case msg.payload {
          "message C" -> {
            let assert Ok(Nil) = queue.ack(ch, meta.delivery_tag, True)
            Nil
          }
          _ -> Nil
        }
      },
    )

  process.sleep(1000)
  let assert Ok("message A") = process.receive(message_subject, 1000)
  let assert Ok("message B") = process.receive(message_subject, 1000)
  let assert Ok("message C") = process.receive(message_subject, 1000)
}
