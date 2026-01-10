-module(carotte_ffi).

-export([start/9, close/1, open_channel/1, publish/5, consume/4, ack/3, unsubscribe/3,
         exchange_declare/2, exchange_delete/4, exchange_bind/5, exchange_unbind/5,
         queue_declare/7, queue_delete/5, queue_bind/5, queue_unbind/4, queue_purge/3,
         header_value_to_header_tuple/1, parse_amqp_headers/1, is_process_alive/1]).

%% =============================================================================
%% CONNECTION ERROR CONVERTER
%% =============================================================================

convert_connection_error({auth_failure, Message}) when is_list(Message) ->
  {error, {connection_auth_failure, list_to_binary(Message)}};
convert_connection_error({auth_failure, Message}) when is_binary(Message) ->
  {error, {connection_auth_failure, Message}};
convert_connection_error(auth_failure) ->
  {error, {connection_auth_failure, <<"Authentication failed">>}};
convert_connection_error(blocked) ->
  {error, connection_blocked};
convert_connection_error(closing) ->
  {error, connection_closed};
convert_connection_error(closed) ->
  {error, connection_closed};
convert_connection_error(econnrefused) ->
  {error, {connection_refused, <<"Connection refused by server">>}};
convert_connection_error(etimedout) ->
  {error, {connection_timeout, <<"Connection timed out">>}};
convert_connection_error(timeout) ->
  {error, {connection_timeout, <<"Operation timed out">>}};
convert_connection_error({connection_refused, Message}) when is_list(Message) ->
  {error, {connection_refused, list_to_binary(Message)}};
convert_connection_error({connection_refused, Message}) when is_binary(Message) ->
  {error, {connection_refused, Message}};
convert_connection_error({shutdown, Reason}) ->
  convert_connection_error(Reason);
convert_connection_error({'EXIT', Reason}) ->
  convert_connection_error(Reason);
convert_connection_error({error, Reason}) ->
  convert_connection_error(Reason);
convert_connection_error(Error) ->
  {error, {connection_unknown_error, list_to_binary(io_lib:format("~p", [Error]))}}.

%% =============================================================================
%% CHANNEL ERROR CONVERTER
%% =============================================================================

convert_channel_error(noproc) ->
  {error, channel_connection_closed};
convert_channel_error({noproc, _}) ->
  {error, channel_connection_closed};
convert_channel_error(closing) ->
  {error, channel_connection_closed};
convert_channel_error(closed) ->
  {error, channel_connection_closed};
convert_channel_error({channel_closed, Reason}) when is_list(Reason) ->
  {error, {channel_closed, list_to_binary(Reason)}};
convert_channel_error({channel_closed, Reason}) when is_binary(Reason) ->
  {error, {channel_closed, Reason}};
convert_channel_error({{shutdown, {server_initiated_close, Code, Message}}, _GenServerInfo}) ->
  convert_channel_error({shutdown, {server_initiated_close, Code, Message}});
convert_channel_error({shutdown, {server_initiated_close, 503, Message}}) when is_list(Message) ->
  {error, {channel_closed, list_to_binary(Message)}};
convert_channel_error({shutdown, {server_initiated_close, 503, Message}}) when is_binary(Message) ->
  {error, {channel_closed, Message}};
convert_channel_error({shutdown, {server_initiated_close, 504, Message}}) when is_list(Message) ->
  {error, {channel_closed, list_to_binary(Message)}};
convert_channel_error({shutdown, {server_initiated_close, 504, Message}}) when is_binary(Message) ->
  {error, {channel_closed, Message}};
convert_channel_error({shutdown, Reason}) ->
  convert_channel_error(Reason);
convert_channel_error({'EXIT', Reason}) ->
  convert_channel_error(Reason);
convert_channel_error({error, Reason}) ->
  convert_channel_error(Reason);
convert_channel_error(Error) ->
  {error, {channel_unknown_error, list_to_binary(io_lib:format("~p", [Error]))}}.

%% =============================================================================
%% EXCHANGE ERROR CONVERTER
%% =============================================================================

convert_exchange_error(noproc) ->
  {error, {exchange_channel_closed, <<"Channel process not found">>}};
convert_exchange_error({noproc, _}) ->
  {error, {exchange_channel_closed, <<"Channel process not found">>}};
convert_exchange_error({{shutdown, {server_initiated_close, Code, Message}}, _GenServerInfo}) ->
  convert_exchange_error({shutdown, {server_initiated_close, Code, Message}});
convert_exchange_error({shutdown, {server_initiated_close, 404, Message}}) when is_list(Message) ->
  {error, {exchange_not_found, list_to_binary(Message)}};
convert_exchange_error({shutdown, {server_initiated_close, 404, Message}}) when is_binary(Message) ->
  {error, {exchange_not_found, Message}};
convert_exchange_error({shutdown, {server_initiated_close, 403, Message}}) when is_list(Message) ->
  {error, {exchange_access_refused, list_to_binary(Message)}};
convert_exchange_error({shutdown, {server_initiated_close, 403, Message}}) when is_binary(Message) ->
  {error, {exchange_access_refused, Message}};
convert_exchange_error({shutdown, {server_initiated_close, 406, Message}}) when is_list(Message) ->
  {error, {exchange_precondition_failed, list_to_binary(Message)}};
convert_exchange_error({shutdown, {server_initiated_close, 406, Message}}) when is_binary(Message) ->
  {error, {exchange_precondition_failed, Message}};
convert_exchange_error({shutdown, {server_initiated_close, 503, Message}}) when is_list(Message) ->
  {error, {exchange_channel_closed, list_to_binary(Message)}};
convert_exchange_error({shutdown, {server_initiated_close, 503, Message}}) when is_binary(Message) ->
  {error, {exchange_channel_closed, Message}};
convert_exchange_error({shutdown, {server_initiated_close, 504, Message}}) when is_list(Message) ->
  {error, {exchange_channel_closed, list_to_binary(Message)}};
convert_exchange_error({shutdown, {server_initiated_close, 504, Message}}) when is_binary(Message) ->
  {error, {exchange_channel_closed, Message}};
convert_exchange_error({amqp_error, not_found, Message}) when is_list(Message) ->
  {error, {exchange_not_found, list_to_binary(Message)}};
convert_exchange_error({amqp_error, not_found, Message}) when is_binary(Message) ->
  {error, {exchange_not_found, Message}};
convert_exchange_error({amqp_error, access_refused, Message}) when is_list(Message) ->
  {error, {exchange_access_refused, list_to_binary(Message)}};
convert_exchange_error({amqp_error, access_refused, Message}) when is_binary(Message) ->
  {error, {exchange_access_refused, Message}};
convert_exchange_error({amqp_error, precondition_failed, Message}) when is_list(Message) ->
  {error, {exchange_precondition_failed, list_to_binary(Message)}};
convert_exchange_error({amqp_error, precondition_failed, Message}) when is_binary(Message) ->
  {error, {exchange_precondition_failed, Message}};
convert_exchange_error({shutdown, Reason}) ->
  convert_exchange_error(Reason);
convert_exchange_error({'EXIT', Reason}) ->
  convert_exchange_error(Reason);
convert_exchange_error({error, Reason}) ->
  convert_exchange_error(Reason);
convert_exchange_error(Error) ->
  {error, {exchange_unknown_error, list_to_binary(io_lib:format("~p", [Error]))}}.

%% =============================================================================
%% QUEUE ERROR CONVERTER
%% =============================================================================

convert_queue_error(noproc) ->
  {error, {queue_channel_closed, <<"Channel process not found">>}};
convert_queue_error({noproc, _}) ->
  {error, {queue_channel_closed, <<"Channel process not found">>}};
convert_queue_error({{shutdown, {server_initiated_close, Code, Message}}, _GenServerInfo}) ->
  convert_queue_error({shutdown, {server_initiated_close, Code, Message}});
convert_queue_error({shutdown, {server_initiated_close, 404, Message}}) when is_list(Message) ->
  {error, {queue_not_found, list_to_binary(Message)}};
convert_queue_error({shutdown, {server_initiated_close, 404, Message}}) when is_binary(Message) ->
  {error, {queue_not_found, Message}};
convert_queue_error({shutdown, {server_initiated_close, 403, Message}}) when is_list(Message) ->
  {error, {queue_access_refused, list_to_binary(Message)}};
convert_queue_error({shutdown, {server_initiated_close, 403, Message}}) when is_binary(Message) ->
  {error, {queue_access_refused, Message}};
convert_queue_error({shutdown, {server_initiated_close, 405, Message}}) when is_list(Message) ->
  {error, {queue_resource_locked, list_to_binary(Message)}};
convert_queue_error({shutdown, {server_initiated_close, 405, Message}}) when is_binary(Message) ->
  {error, {queue_resource_locked, Message}};
convert_queue_error({shutdown, {server_initiated_close, 406, Message}}) when is_list(Message) ->
  {error, {queue_precondition_failed, list_to_binary(Message)}};
convert_queue_error({shutdown, {server_initiated_close, 406, Message}}) when is_binary(Message) ->
  {error, {queue_precondition_failed, Message}};
convert_queue_error({shutdown, {server_initiated_close, 503, Message}}) when is_list(Message) ->
  {error, {queue_channel_closed, list_to_binary(Message)}};
convert_queue_error({shutdown, {server_initiated_close, 503, Message}}) when is_binary(Message) ->
  {error, {queue_channel_closed, Message}};
convert_queue_error({shutdown, {server_initiated_close, 504, Message}}) when is_list(Message) ->
  {error, {queue_channel_closed, list_to_binary(Message)}};
convert_queue_error({shutdown, {server_initiated_close, 504, Message}}) when is_binary(Message) ->
  {error, {queue_channel_closed, Message}};
convert_queue_error({amqp_error, not_found, Message}) when is_list(Message) ->
  {error, {queue_not_found, list_to_binary(Message)}};
convert_queue_error({amqp_error, not_found, Message}) when is_binary(Message) ->
  {error, {queue_not_found, Message}};
convert_queue_error({amqp_error, access_refused, Message}) when is_list(Message) ->
  {error, {queue_access_refused, list_to_binary(Message)}};
convert_queue_error({amqp_error, access_refused, Message}) when is_binary(Message) ->
  {error, {queue_access_refused, Message}};
convert_queue_error({amqp_error, precondition_failed, Message}) when is_list(Message) ->
  {error, {queue_precondition_failed, list_to_binary(Message)}};
convert_queue_error({amqp_error, precondition_failed, Message}) when is_binary(Message) ->
  {error, {queue_precondition_failed, Message}};
convert_queue_error({amqp_error, resource_locked, Message}) when is_list(Message) ->
  {error, {queue_resource_locked, list_to_binary(Message)}};
convert_queue_error({amqp_error, resource_locked, Message}) when is_binary(Message) ->
  {error, {queue_resource_locked, Message}};
convert_queue_error({shutdown, Reason}) ->
  convert_queue_error(Reason);
convert_queue_error({'EXIT', Reason}) ->
  convert_queue_error(Reason);
convert_queue_error({error, Reason}) ->
  convert_queue_error(Reason);
convert_queue_error(Error) ->
  {error, {queue_unknown_error, list_to_binary(io_lib:format("~p", [Error]))}}.

%% =============================================================================
%% PUBLISH ERROR CONVERTER
%% =============================================================================

convert_publish_error(noproc) ->
  {error, {publish_channel_closed, <<"Channel process not found">>}};
convert_publish_error({noproc, _}) ->
  {error, {publish_channel_closed, <<"Channel process not found">>}};
convert_publish_error({{shutdown, {server_initiated_close, Code, Message}}, _GenServerInfo}) ->
  convert_publish_error({shutdown, {server_initiated_close, Code, Message}});
convert_publish_error({shutdown, {server_initiated_close, 312, Message}}) when is_list(Message) ->
  {error, {publish_no_route, list_to_binary(Message)}};
convert_publish_error({shutdown, {server_initiated_close, 312, Message}}) when is_binary(Message) ->
  {error, {publish_no_route, Message}};
convert_publish_error({shutdown, {server_initiated_close, 503, Message}}) when is_list(Message) ->
  {error, {publish_channel_closed, list_to_binary(Message)}};
convert_publish_error({shutdown, {server_initiated_close, 503, Message}}) when is_binary(Message) ->
  {error, {publish_channel_closed, Message}};
convert_publish_error({shutdown, {server_initiated_close, 504, Message}}) when is_list(Message) ->
  {error, {publish_channel_closed, list_to_binary(Message)}};
convert_publish_error({shutdown, {server_initiated_close, 504, Message}}) when is_binary(Message) ->
  {error, {publish_channel_closed, Message}};
convert_publish_error({no_route, Message}) when is_list(Message) ->
  {error, {publish_no_route, list_to_binary(Message)}};
convert_publish_error({no_route, Message}) when is_binary(Message) ->
  {error, {publish_no_route, Message}};
convert_publish_error({shutdown, Reason}) ->
  convert_publish_error(Reason);
convert_publish_error({'EXIT', Reason}) ->
  convert_publish_error(Reason);
convert_publish_error({error, Reason}) ->
  convert_publish_error(Reason);
convert_publish_error(Error) ->
  {error, {publish_unknown_error, list_to_binary(io_lib:format("~p", [Error]))}}.

%% =============================================================================
%% CONSUME ERROR CONVERTER
%% =============================================================================

convert_consume_error(noproc) ->
  {error, {consume_channel_closed, <<"Channel process not found">>}};
convert_consume_error({noproc, _}) ->
  {error, {consume_channel_closed, <<"Channel process not found">>}};
convert_consume_error({{shutdown, {server_initiated_close, Code, Message}}, _GenServerInfo}) ->
  convert_consume_error({shutdown, {server_initiated_close, Code, Message}});
convert_consume_error({shutdown, {server_initiated_close, 503, Message}}) when is_list(Message) ->
  {error, {consume_channel_closed, list_to_binary(Message)}};
convert_consume_error({shutdown, {server_initiated_close, 503, Message}}) when is_binary(Message) ->
  {error, {consume_channel_closed, Message}};
convert_consume_error({shutdown, {server_initiated_close, 504, Message}}) when is_list(Message) ->
  {error, {consume_channel_closed, list_to_binary(Message)}};
convert_consume_error({shutdown, {server_initiated_close, 504, Message}}) when is_binary(Message) ->
  {error, {consume_channel_closed, Message}};
convert_consume_error(unexpected_response) ->
  {error, {consume_unknown_error, <<"Unexpected response from broker">>}};
convert_consume_error({shutdown, Reason}) ->
  convert_consume_error(Reason);
convert_consume_error({'EXIT', Reason}) ->
  convert_consume_error(Reason);
convert_consume_error({error, Reason}) ->
  convert_consume_error(Reason);
convert_consume_error(Error) ->
  {error, {consume_unknown_error, list_to_binary(io_lib:format("~p", [Error]))}}.

-record(amqp_params_network,
        {username = <<"guest">>,
         password = <<"guest">>,
         virtual_host = <<"/">>,
         host = "localhost",
         port = undefined,
         channel_max = 2047,
         frame_max = 0,
         heartbeat = 10,
         connection_timeout = 60000,
         ssl_options = none,
         auth_mechanisms = [fun amqp_auth_mechanisms:plain/3, fun amqp_auth_mechanisms:amqplain/3],
         client_properties = [],
         socket_options = []}).

start(Username,
      Password,
      VirtualHost,
      Host,
      Port,
      ChannelMax,
      FrameMax,
      Heartbeat,
      ConnectionTimeout) ->
  case amqp_connection:start(#amqp_params_network{username = Username,
                                                  password = Password,
                                                  virtual_host = VirtualHost,
                                                  host = binary_to_list(Host),
                                                  port = Port,
                                                  channel_max = ChannelMax,
                                                  frame_max = FrameMax,
                                                  heartbeat = Heartbeat,
                                                  connection_timeout = ConnectionTimeout})
  of
    {ok, Pid} ->
      {ok, Pid};
    {error, Error} ->
      convert_connection_error(Error)
  end.

open_channel({client, Pid, _Config}) ->
  case amqp_connection:open_channel(Pid) of
    {ok, ChannelPid} ->
      {ok, {channel, ChannelPid}};
    {error, Error} ->
      convert_channel_error(Error)
  end.

-record('exchange.declare',
        {ticket = 0,
         exchange,
         type = <<"direct">>,
         passive = false,
         durable = false,
         auto_delete = false,
         internal = false,
         nowait = false,
         arguments = []}).

exchange_declare({channel, ChannelPid},
                 {exchange, Name, Type, Durable, AutoDelete, Internal, Nowait}) ->
  try
    Result =
      amqp_channel:call(ChannelPid,
                        #'exchange.declare'{exchange = Name,
                                            type = atom_to_binary(Type),
                                            durable = Durable,
                                            auto_delete = AutoDelete,
                                            internal = Internal,
                                            nowait = Nowait,
                                            arguments = []}),
    case {Nowait, Result} of
      {true, ok} ->
        {ok, nil};
      {_, {'exchange.declare_ok'}} ->
        {ok, nil};
      {_, Error} ->
        convert_exchange_error(Error)
    end
  catch
    exit:Reason ->
      convert_exchange_error(Reason);
    error:Reason ->
      convert_exchange_error(Reason)
  end.

-record('exchange.delete', {ticket = 0, exchange, if_unused = false, nowait = false}).

exchange_delete({channel, ChannelPid}, Name, IfUnused, Nowait) ->
  try
    case {Nowait,
          amqp_channel:call(ChannelPid,
                            #'exchange.delete'{exchange = Name,
                                               if_unused = IfUnused,
                                               nowait = Nowait})}
    of
      {true, ok} ->
        {ok, nil};
      {_, {'exchange.delete_ok'}} ->
        {ok, nil};
      {_, Error} ->
        convert_exchange_error(Error)
    end
  catch
    exit:Reason ->
      convert_exchange_error(Reason);
    error:Reason ->
      convert_exchange_error(Reason)
  end.

-record('exchange.bind',
        {ticket = 0, destination, source, routing_key = <<"">>, nowait = false, arguments = []}).

exchange_bind({channel, ChannelPid}, Source, Destination, RoutingKey, Nowait) ->
  try
    case {Nowait,
          amqp_channel:call(ChannelPid,
                            #'exchange.bind'{destination = Destination,
                                             source = Source,
                                             routing_key = RoutingKey,
                                             nowait = Nowait})}
    of
      {true, ok} ->
        {ok, nil};
      {_, {'exchange.bind_ok'}} ->
        {ok, nil};
      {_, Error} ->
        convert_exchange_error(Error)
    end
  catch
    exit:Reason ->
      convert_exchange_error(Reason);
    error:Reason ->
      convert_exchange_error(Reason)
  end.

-record('exchange.unbind',
        {ticket = 0, destination, source, routing_key = <<"">>, nowait = false, arguments = []}).

exchange_unbind({channel, ChannelPid}, Source, Destination, RoutingKey, Nowait) ->
  try
    case {Nowait,
          amqp_channel:call(ChannelPid,
                            #'exchange.unbind'{destination = Destination,
                                               source = Source,
                                               routing_key = RoutingKey,
                                               nowait = Nowait})}
    of
      {true, ok} ->
        {ok, nil};
      {_, {'exchange.unbind_ok'}} ->
        {ok, nil};
      {_, Error} ->
        convert_exchange_error(Error)
    end
  catch
    exit:Reason ->
      convert_exchange_error(Reason);
    error:Reason ->
      convert_exchange_error(Reason)
  end.

-record('queue.declare',
        {ticket = 0,
         queue = <<"">>,
         passive = false,
         durable = false,
         exclusive = false,
         auto_delete = false,
         nowait = false,
         arguments = []}).

queue_declare({channel, ChannelPid},
              Queue,
              Passive,
              Durable,
              Exclusive,
              AutoDelete,
              Nowait) ->
  try
    case {Nowait,
          amqp_channel:call(ChannelPid,
                            #'queue.declare'{queue = Queue,
                                             passive = Passive,
                                             durable = Durable,
                                             exclusive = Exclusive,
                                             auto_delete = AutoDelete,
                                             nowait = Nowait})}
    of
      {true, ok} ->
        {ok, nil};
      {_, {'queue.declare_ok', ReturnedQueue, MessageCount, ConsumerCount}} ->
        {ok, {queue, ReturnedQueue, MessageCount, ConsumerCount}};
      {_, Error} ->
        convert_queue_error(Error)
    end
  catch
    exit:Reason ->
      convert_queue_error(Reason);
    error:Reason ->
      convert_queue_error(Reason)
  end.

-record('queue.delete',
        {ticket = 0, queue = <<"">>, if_unused = false, if_empty = false, nowait = false}).

queue_delete({channel, ChannelPid}, Queue, IfUnused, IfEmpty, Nowait) ->
  try
    case {Nowait,
          amqp_channel:call(ChannelPid,
                            #'queue.delete'{queue = Queue,
                                            if_unused = IfUnused,
                                            if_empty = IfEmpty,
                                            nowait = Nowait})}
    of
      {true, ok} ->
        {ok, nil};
      {_, {'queue.delete_ok', MessageCount}} ->
        {ok, MessageCount};
      {_, Error} ->
        convert_queue_error(Error)
    end
  catch
    exit:Reason ->
      convert_queue_error(Reason);
    error:Reason ->
      convert_queue_error(Reason)
  end.

-record('queue.bind',
        {ticket = 0,
         queue = <<"">>,
         exchange,
         routing_key = <<"">>,
         nowait = false,
         arguments = []}).

queue_bind({channel, ChannelPid}, Queue, Exchange, RoutingKey, Nowait) ->
  try
    case {Nowait,
          amqp_channel:call(ChannelPid,
                            #'queue.bind'{queue = Queue,
                                          exchange = Exchange,
                                          routing_key = RoutingKey,
                                          nowait = Nowait})}
    of
      {true, ok} ->
        {ok, nil};
      {_, {'queue.bind_ok'}} ->
        {ok, nil};
      {_, Error} ->
        convert_queue_error(Error)
    end
  catch
    exit:Reason ->
      convert_queue_error(Reason);
    error:Reason ->
      convert_queue_error(Reason)
  end.

-record('queue.unbind',
        {ticket = 0, queue = <<"">>, exchange, routing_key = <<"">>, arguments = []}).

queue_unbind({channel, ChannelPid}, Queue, Exchange, RoutingKey) ->
  try
    case amqp_channel:call(ChannelPid,
                           #'queue.unbind'{queue = Queue,
                                           exchange = Exchange,
                                           routing_key = RoutingKey})
    of
      {'queue.unbind_ok'} ->
        {ok, nil};
      Error ->
        convert_queue_error(Error)
    end
  catch
    exit:Reason ->
      convert_queue_error(Reason);
    error:Reason ->
      convert_queue_error(Reason)
  end.

-record('queue.purge', {ticket = 0, queue = <<"">>, nowait = false}).

queue_purge({channel, ChannelPid}, Queue, Nowait) ->
  try
    case {Nowait,
          amqp_channel:call(ChannelPid, #'queue.purge'{queue = Queue, nowait = Nowait})}
    of
      {true, ok} ->
        {ok, nil};
      {_, {'queue.purge_ok', MessageCount}} ->
        {ok, MessageCount};
      {_, Error} ->
        convert_queue_error(Error)
    end
  catch
    exit:Reason ->
      convert_queue_error(Reason);
    error:Reason ->
      convert_queue_error(Reason)
  end.

-record('basic.publish',
        {ticket = 0,
         exchange = <<"">>,
         routing_key = <<"">>,
         mandatory = false,
         immediate = false}).
-record('P_basic',
        {content_type,
         content_encoding,
         headers,
         delivery_mode,
         priority,
         correlation_id,
         reply_to,
         expiration,
         message_id,
         timestamp,
         type,
         user_id,
         app_id,
         cluster_id}).
-record(amqp_msg, {props = #'P_basic'{}, payload = <<>>}).

publish({channel, ChannelPid}, Exchange, RoutingKey, Payload, Proplist) ->
  try
    Headers =
      case proplists:get_value(message_headers_ffi, Proplist, undefined) of
        {header_list, HeaderList} ->
          HeaderList;
        _ ->
          undefined
      end,
    Props =
      #'P_basic'{content_type = proplists:get_value(content_type_ffi, Proplist, undefined),
                 content_encoding = proplists:get_value(content_encoding_ffi, Proplist, undefined),
                 headers = Headers,
                 delivery_mode =
                   case proplists:get_value(persistent_ffi, Proplist, false) of
                     true ->
                       2;
                     false ->
                       1
                   end,
                 priority = proplists:get_value(priority_ffi, Proplist, undefined),
                 correlation_id = proplists:get_value(correlation_id_ffi, Proplist, undefined),
                 reply_to = proplists:get_value(reply_to_ffi, Proplist, undefined),
                 expiration = proplists:get_value(expiration_ffi, Proplist, undefined),
                 message_id = proplists:get_value(message_id_ffi, Proplist, undefined),
                 timestamp = proplists:get_value(timestamp_ffi, Proplist, undefined),
                 type = proplists:get_value(type_ffi, Proplist, undefined),
                 user_id = proplists:get_value(user_id_ffi, Proplist, undefined),
                 app_id = proplists:get_value(app_id_ffi, Proplist, undefined),
                 cluster_id = proplists:get_value(cluster_id_ffi, Proplist, undefined)},
    case amqp_channel:call(ChannelPid,
                           #'basic.publish'{exchange = Exchange,
                                            routing_key = RoutingKey,
                                            mandatory =
                                              proplists:get_value(mandatory_ffi, Proplist, false),
                                            immediate =
                                              proplists:get_value(immediate_ffi, Proplist, false)},
                           #amqp_msg{props = Props, payload = Payload})
    of
      ok ->
        {ok, nil};
      Error ->
        convert_publish_error(Error)
    end
  catch
    exit:Reason ->
      convert_publish_error(Reason);
    error:Reason ->
      convert_publish_error(Reason)
  end.

-record('basic.consume',
        {ticket = 0,
         queue = <<"">>,
         consumer_tag = <<"">>,
         no_local = false,
         no_ack = false,
         exclusive = false,
         nowait = false,
         arguments = []}).

consume({channel, ChannelPid}, Queue, Pid, NoAck) ->
  % AMQP will send messages directly to Pid, including basic.consume_ok
  case amqp_channel:subscribe(ChannelPid,
                              #'basic.consume'{queue = Queue, no_ack = NoAck},
                              Pid)
  of
    {'basic.consume_ok', ConsumerTag_} ->
      % The AMQP client might send basic.consume_ok directly to Pid
      % Don't send it again
      {ok, ConsumerTag_};
    Error ->
      convert_consume_error(Error)
  end.

-record('basic.ack', {delivery_tag = 0, multiple = false}).

ack({channel, ChannelPid}, DeliveryTag, Multiple) ->
  try
    case amqp_channel:call(ChannelPid,
                           #'basic.ack'{delivery_tag = DeliveryTag, multiple = Multiple})
    of
      ok ->
        {ok, nil};
      Error ->
        convert_consume_error(Error)
    end
  catch
    exit:Reason ->
      convert_consume_error(Reason);
    error:Reason ->
      convert_consume_error(Reason)
  end.

-record('basic.cancel', {consumer_tag, nowait = false}).

unsubscribe({channel, ChannelPid}, ConsumerTag, Nowait) ->
  try
    case {Nowait, amqp_channel:call(ChannelPid, #'basic.cancel'{consumer_tag = ConsumerTag})}
    of
      {true, ok} ->
        {ok, nil};
      {_, {'basic.cancel_ok', _}} ->
        {ok, nil};
      {_, Error} ->
        convert_consume_error(Error)
    end
  catch
    exit:Reason ->
      convert_consume_error(Reason);
    error:Reason ->
      convert_consume_error(Reason)
  end.

close({client, Pid, _Config}) ->
  case amqp_connection:close(Pid) of
    ok ->
      {ok, nil};
    {error, Error} ->
      convert_connection_error(Error)
  end.

header_value_to_header_tuple(Value) ->
  case Value of
    {bool_header, Inner} ->
      {bool, Inner};
    {float_header, Inner} ->
      {float, Inner};
    {int_header, Inner} ->
      {long, Inner};
    {string_header, Inner} ->
      {longstr, Inner};
    {list_header, Inner} ->
      {array,
       lists:map(fun({ArrayValue}) -> {header_value_to_header_tuple(ArrayValue)} end, Inner)}
  end.

% Convert AMQP headers proplist to Gleam HeaderList format
% AMQP headers: [{Name :: binary(), Type :: atom(), Value :: term()}, ...]
% Gleam HeaderList: {header_list, [{Name, Type, Value}, ...]}
parse_amqp_headers(undefined) ->
  {header_list, []};
parse_amqp_headers(Headers) when is_list(Headers) ->
  {header_list, Headers};
parse_amqp_headers(_) ->
  {header_list, []}.

% Check if the connection process is alive
is_process_alive({client, Pid, _Config}) ->
  erlang:is_process_alive(Pid).
