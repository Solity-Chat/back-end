-module(toppage_h).

-export([
         init/2,
         allowed_methods/2,
         content_types_provided/2,
         content_types_accepted/2,
         options/2,
         resource_exists/2,
         delete_resource/2,
         is_authorized/2
        ]).

-export([
         db_to_json/2,
         db_to_text/2,
         text_to_db/2
        ]).

-record(state, {op}).

init(Req, Opts) ->
    [Op | _] = Opts,
    State = #state{op=Op},
	{cowboy_rest, Req, State}.

allowed_methods(Req, State) ->
    Methods = [<<"GET">>, <<"POST">>, <<"DELETE">>],
    {Methods, Req, State}.

is_authorized(Req, State) -> 
  case cowboy_req:method(Req) of
    <<"GET">> ->
        {true, Req, State};
    <<"POST">> ->
        {true, Req, State};
    <<"OPTIONS">> ->
      {true, Req, State}
  end.

content_types_provided(Req, State) ->
    {[
      {<<"application/json">>, db_to_json},
      {<<"text/plain">>, db_to_text}
     ], Req, State}.

content_types_accepted(Req, State) ->
    {[
      {<<"text/plain">>, text_to_db},
      {<<"application/x-www-form-urlencoded">>, text_to_db}
     ], Req, State}.

options(Req0, State) ->
    Req1 = cowboy_req:set_resp_header(
        <<"access-control-allow-methods">>, <<"GET, OPTIONS">>, Req0),
    Req2 = cowboy_req:set_resp_header(
        <<"access-control-allow-origin">>, <<"*">>, Req1),
    Req3 = cowboy_req:set_resp_header(
        <<"access-control-allow-headers">>, <<"authorization">>, Req2),
    {ok, Req3, State}.

db_to_json(Req, #state{op=Op} = State) ->
    {Body, Req1, State1} = case Op of
        list ->
            get_record_list(Req, State);
        get ->
            get_one_record(Req, State);
        get_user ->
            get_user_record(Req, State);
        get_user_by_name ->
            get_user_record_by_user_name(Req, State);
        get_all_users ->
            get_all_users_records(Req, State);
        get_conversation ->
            get_conversation_record(Req, State);
        get_conversations_by_user ->
            get_conversations_by_user(Req, State);
        get_message ->
            get_message_record(Req, State);
        get_messages_by_conv ->
            get_messages_by_conv(Req, State);
        help ->
            get_help(Req, State)
    end,
	{Body, Req1, State1}.

db_to_text(Req, #state{op=Op} = State) ->
    {Body, Req1, State1} = case Op of
        list ->
            get_record_list_text(Req, State);
        get ->
            get_one_record_text(Req, State);
        help ->
            get_help_text(Req, State)
    end,
	{Body, Req1, State1}.

text_to_db(Req, #state{op=Op} = State) ->
    {Body, Req1, State1} = case Op of
        create_conversation ->
            create_conversation_record_to_json(Req, State);
        create_user ->
            create_user_record_to_json(Req, State);
        create_message ->
            create_message_record_to_json(Req, State);
        delete ->
            delete_record_to_json(Req, State);
        update ->
            update_record_to_json(Req, State)
    end,
	{Body, Req1, State1}.

resource_exists(Req, State) ->
    case cowboy_req:method(Req) of
        <<"DELETE">> ->
            RecordId = cowboy_req:binding(record_id, Req),
            RecordId1 = binary_to_list(RecordId),
            {ok, Recordfilename} = application:get_env(
                 backend, records_file_name),
            {ok, _} = dets:open_file(
                records_db, [{file, Recordfilename}, {type, set}]),
            Records = dets:lookup(records_db, RecordId1),
            ok = dets:close(records_db),
            Response = case Records of
                [_] ->
                    {true, Req, State};
                _ ->
                    {false, Req, State}
            end,
            Response;
        _ ->
            {true, Req, State}
    end.

delete_resource(Req, State) ->
    RecordId = cowboy_req:binding(record_id, Req),
    RecordId1 = binary_to_list(RecordId),
    {ok, Recordfilename} = application:get_env(backend, records_file_name),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Result = dets:delete(records_db, RecordId1),
    ok = dets:close(records_db),
    Response = case Result of
        ok ->
            true;
        {error, _Reason} ->
            false
    end,
    {Response, Req, State}.

get_record_list(Req, State) ->
    {ok, Recordfilename} = application:get_env(backend, records_file_name),
    dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    F = fun (Item, Acc) -> Acc1 = [Item | Acc], Acc1 end,
    Items = dets:foldl(F, [], records_db),
    dets:close(records_db),
    Items1 = lists:sort(Items),
    Body = "
{
    \"list\": \"~p\",
}",
    Body1 = io_lib:format(Body, [Items1]),
    {Body1, Req, State}.

get_record_list_text(Req, State) ->
    {ok, Recordfilename} = application:get_env(backend, records_file_name),
    dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    F1 = fun (Item, Acc) -> Acc1 = [Item | Acc], Acc1 end,
    Items = dets:foldl(F1, [], records_db),
    dets:close(records_db),
    F2 = fun ({User_id, User_name, User_bio, User_password, User_conversations, User_friends}, Acc) ->
                 Val = io_lib:format("- ~s ~s ~s ~s ~s ~s ~n", [User_id, User_name, User_bio, User_password, User_conversations, User_friends]),
                 [Val | Acc]
         end,
    Items1 = lists:foldl(F2, [], Items),
    Items2 = lists:sort(Items1),
    Items3 = lists:flatten(lists:concat(Items2)),
    Body = "
list: ~p,
",
    Body1 = io_lib:format(Body, [Items3]),
    {Body1, Req, State}.

get_one_record(Req, State) ->
    RecordId = cowboy_req:binding(record_id, Req),
    RecordId1 = binary_to_list(RecordId),
    {ok, Recordfilename} = application:get_env(backend, records_file_name),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Records = dets:lookup(records_db, RecordId1),
    ok = dets:close(records_db),
    Body = case Records of
        [{RecordId2, Data}] ->
            io_lib:format("{\"id\": \"~s\", \"record\": \"~s\"}",
                          [RecordId2, binary_to_list(Data)]);
        [] ->
            io_lib:format("{\"not_found\": \"record ~p not found\"}",
                          [RecordId1]);
        _ ->
            io_lib:format("{\"extra_records\": \"extra records for ~p\"}",
                          [RecordId1])
    end,
    {list_to_binary(Body), Req, State}.

get_one_record_text(Req, State) ->
    RecordId = cowboy_req:binding(record_id, Req),
    RecordId1 = binary_to_list(RecordId),
    {ok, Recordfilename} = application:get_env(backend, records_file_name),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Records = dets:lookup(records_db, RecordId1),
    ok = dets:close(records_db),
    Body = case Records of
        [{RecordId2, Data}] ->
            io_lib:format("id: \"~s\", record: \"~s\"",
                          [RecordId2, binary_to_list(Data)]);
        [] ->
            io_lib:format("{not_found: record ~p not found}",
                          [RecordId1]);
        _ ->
            io_lib:format("{extra_records: extra records for ~p",
                          [RecordId1])
    end,
    {list_to_binary(Body), Req, State}.

get_user_record(Req, State) ->
    RecordId = cowboy_req:binding(record_id, Req),
    RecordId1 = binary_to_list(RecordId),
    Body = get_record_by_id(records_file_name_user, user, RecordId1),
    Req1 = cowboy_req:set_resp_header(
      <<"access-control-allow-origin">>, <<"*">>, Req),
    {Body, Req1, State}.

get_conversation_record(Req, State) ->
    RecordId = cowboy_req:binding(record_id, Req),
    RecordId1 = binary_to_list(RecordId),
    Body = get_record_by_id(records_file_name_conversation, conversation, RecordId1),
    Req1 = cowboy_req:set_resp_header(
      <<"access-control-allow-origin">>, <<"*">>, Req),
    {Body, Req1, State}.

get_message_record(Req, State) ->
    RecordId = cowboy_req:binding(record_id, Req),
    RecordId1 = binary_to_list(RecordId),
    Body = get_record_by_id(records_file_name_message, message, RecordId1),
    Req1 = cowboy_req:set_resp_header(
      <<"access-control-allow-origin">>, <<"*">>, Req),
    {Body, Req1, State}.

get_record_by_id(Record_file_name, Type, RecordId) ->
    {ok, Recordfilename} = application:get_env(backend, Record_file_name),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Records = dets:lookup(records_db, RecordId),
    ok = dets:close(records_db),
    Body = get_body(Records, Type),
    Body.

get_user_record_by_user_name(Req, State) ->
    Username = cowboy_req:binding(user_name, Req),
    Username1 = binary_to_list(Username),
    {ok, Recordfilename} = application:get_env(backend, records_file_name_user),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Records = dets:select(records_db, [{{'_', list_to_binary(Username1), '_', '_', '_', '_'}, [], ['$_']}]),
    ok = dets:close(records_db),
    Body = get_body(Records, user),
    Req1 = cowboy_req:set_resp_header(
      <<"access-control-allow-origin">>, <<"*">>, Req),
    {Body, Req1, State}.

get_conversations_by_user(Req, State) ->
    Username = cowboy_req:binding(user_name, Req),
    Username1 = binary_to_list(Username),
    {ok, Recordfilename} = application:get_env(backend, records_file_name_user),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Records = dets:select(records_db, [{{'_', list_to_binary(Username1), '_', '_', '_', '_'}, [], ['$_']}]),
    ok = dets:close(records_db),
    Body = case Records of
        [] -> 
            io_lib:format("{not_found: record ~p not found",
                          [Username1]);
        _ ->
            lists:foldl(
                fun(Id, Acc) ->
                    Acc ++ get_record_by_id(records_file_name_conversation, conversation, Id) ++ ", "
                end, 
                "[", 
                element(5, hd(Records)))
    end,
    Body1 = string:slice(Body, 0, string:length(Body) - 2) ++ "]",
    Req1 = cowboy_req:set_resp_header(
      <<"access-control-allow-origin">>, <<"*">>, Req),
    {Body1, Req1, State}.

get_messages_by_conv(Req, State) ->
    RecordId = cowboy_req:binding(conv_id, Req),
    RecordId1 = binary_to_list(RecordId),
    {ok, Recordfilename} = application:get_env(backend, records_file_name_conversation),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Records = dets:lookup(records_db, RecordId1),
    ok = dets:close(records_db),
    Body = case Records of
        [] ->
            io_lib:format("{not_found: record ~p not found}",
                          [RecordId1]);
        _ ->
            lists:foldl(
            fun (Id, Acc) ->
                Acc ++ get_record_by_id(records_file_name_message, message, Id) ++ ", "
            end,
            "[",
            element(4, hd(Records)))
    end,
    Body1 = string:slice(Body, 0, string:length(Body) - 2) ++ "]",
    Req1 = cowboy_req:set_resp_header(
      <<"access-control-allow-origin">>, <<"*">>, Req),
    {Body1, Req1, State}.

get_all_users_records(Req, State) ->
    {ok, Recordfilename} = application:get_env(backend, records_file_name_user),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Records = dets:select(records_db, [{{'_', '_', '_', '_', '_', '_'}, [], ['$_']}]),
    ok = dets:close(records_db),
    Body = case Records of
        [] -> 
            io_lib:format("{not_found: record not found}");
        _ ->
            lists:foldl(
                fun(User, Acc) ->
                    Acc ++ get_body([User], user) ++ ", "
                end, 
                "[", 
            Records)
    end,
    Body1 = string:slice(Body, 0, string:length(Body) - 2) ++ "]",
    Req1 = cowboy_req:set_resp_header(
      <<"access-control-allow-origin">>, <<"*">>, Req),
    {Body1, Req1, State}.

get_body(Records, conversation) ->
    case Records of
        [{Conversation_id, User_participant1, User_participant2, Conversation_messages}] ->
            Conversation_messages1 = [get_record_by_id(records_file_name_message, message, Id) || Id <- Conversation_messages],
            io_lib:format(
                "{
                    \"conversation_id\": \"~s\",
                    \"user_participant1\": \"~s\",
                    \"user_participant2\": \"~s\",
                    \"conversation_messages\": [~s]
                }",
                        [
                            Conversation_id,
                            binary_to_list(User_participant1),
                            binary_to_list(User_participant2),
                            Conversation_messages1
                        ]);
        [] ->
            io_lib:format("{not_found: record not found}", []);
        _ ->
            io_lib:format("{extra_records: extra records}", [])
    end;

get_body(Records, user) ->
    case Records of
        [{User_id, User_name, User_bio, User_password, User_conversations, User_friends}] ->
            User_conversations1 = [get_record_by_id(records_file_name_conversation, conversation, Id) || Id <- User_conversations],
            io_lib:format(
                "{
                    \"user_id\": \"~s\",
                    \"user_name\": \"~s\",
                    \"user_bio\": \"~s\",
                    \"user_password\": \"~s\",
                    \"user_conversations\": [~s],
                    \"user_friends\": ~p
                }",
                        [
                            User_id,
                            binary_to_list(User_name),
                            binary_to_list(User_bio),
                            binary_to_list(User_password),
                            User_conversations1,
                            User_friends
                        ]);
        [] ->
            io_lib:format("{not_found: record not found}", []);
        _ ->
            io_lib:format("{extra_records: extra records", [])
    end;

get_body(Records, message) ->
    case Records of
        [{Message_id, User_id, Message_content, Message_status, Conversation_id, Time_sent}] ->
            io_lib:format(
                "{
                    \"message_id\": \"~s\",
                    \"user_id\": \"~s\",
                    \"message_content\": \"~s\",
                    \"message_status\": \"~s\",
                    \"conversation_id\": \"~s\",
                    \"time_sent\": \"~s\"
                }",
                        [
                            Message_id,
                            User_id,
                            binary_to_list(Message_content),
                            binary_to_list(Message_status),
                            Conversation_id,
                            binary_to_list(Time_sent)
                        ]);
        [] ->
            io_lib:format("{not_found: record not found}", []);
        _ ->
            io_lib:format("{extra_records: extra records", [])
    end.

 create_user_record_to_json(Req, State) ->
    {
        ok,
        [
        {<<"user_name">>, User_name},
        {<<"user_bio">>, User_bio},
        {<<"user_password">>, User_password}
        ], 
        Req1 
    } = cowboy_req:read_urlencoded_body(Req),
    User_id = generate_id(state_file_name_user),
    Content = {User_id, User_name, User_bio, User_password, [], []},
    {ok, Recordfilename} = application:get_env(backend, records_file_name_user),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    ok = dets:insert(records_db, Content),
    ok = dets:sync(records_db),
    ok = dets:close(records_db),
    case cowboy_req:method(Req1) of
        <<"POST">> ->
            Response = io_lib:format("/get_user/~s", [User_id]),
            
            {{true, list_to_binary(Response)}, Req1, State};
        _ ->
            {true, Req1, State}
    end.

create_conversation_record_to_json(Req, State) -> 
    {
        ok,
        [
        {<<"user_participant1">>, User_participant1},
        {<<"user_participant2">>, User_participant2}
        ], 
        Req1 
    } = cowboy_req:read_urlencoded_body(Req),
    Conversation_id = generate_id(state_file_name_conversation),
    Content = {Conversation_id, User_participant1, User_participant2, []},
    ok = insert_to_db(records_file_name_conversation, Content),
    {ok, Recordfilename} = application:get_env(backend, records_file_name_user),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Records = dets:select(records_db, [
            {{'_', User_participant1, '_', '_', '_', '_'}, [], ['$_']},
            {{'_', User_participant2, '_', '_', '_', '_'}, [], ['$_']}
        ]),
    ok = dets:close(records_db),
    case Records of
        [] -> ok;
        _ -> [insert_to_db(records_file_name_user, setelement(5, Record, [Conversation_id | element(5, Record)])) || Record <- Records]
    end,
    case cowboy_req:method(Req1) of
        <<"POST">> ->
            Response = io_lib:format("/get_conversation/~s", [Conversation_id]),
            {{true, list_to_binary(Response)}, Req1, State};
        _ ->
            {true, Req1, State}
    end.

create_message_record_to_json(Req, State) ->
    {
        ok,
        [
        {<<"user_id">>, User_id},
        {<<"message_content">>, Message_content},
        {<<"message_status">>, Message_status},
        {<<"time_sent">>, Time_sent},
        {<<"conversation_id">>, Conversation_id}
        ], 
        Req1 
    } = cowboy_req:read_urlencoded_body(Req),
    Message_id = generate_id(state_file_name_message),
    Content = {Message_id, binary_to_list(User_id), Message_content, Message_status, binary_to_list(Conversation_id), Time_sent},
    ok = insert_to_db(records_file_name_message, Content),
    {ok, Recordfilename} = application:get_env(backend, records_file_name_conversation),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    Records = dets:lookup(records_db, binary_to_list(Conversation_id)),
    ok = dets:close(records_db),
    case Records of
        [] -> ok;
        _ -> insert_to_db(records_file_name_conversation, setelement(4, hd(Records), [Message_id | element(4, hd(Records))]))
    end,
    case cowboy_req:method(Req1) of
        <<"POST">> ->
            Response = io_lib:format("/get_message/~s", [Message_id]),
            {{true, list_to_binary(Response)}, Req1, State};
        _ ->
            {true, Req1, State}
    end.

insert_to_db(Record_file_name, Content) -> 
    {ok, Recordfilename} = application:get_env(backend, Record_file_name),
    {ok, _} = dets:open_file(records_db, [{file, Recordfilename}, {type, set}]),
    ok = dets:insert(records_db, Content),
    ok = dets:sync(records_db),
    ok = dets:close(records_db),
    ok.

update_record_to_json(Req, State) ->
    case cowboy_req:method(Req) of
        <<"POST">> ->
            RecId = cowboy_req:binding(record_id, Req),
            RecId1 = binary_to_list(RecId),
            {ok, [{<<"content">>, NewContent}], Req1} =
                cowboy_req:read_urlencoded_body(Req),
            {ok, Recordfilename} = application:get_env(
                backend, records_file_name),
            {ok, _} = dets:open_file(
                records_db, [{file, Recordfilename}, {type, set}]),
            DBResponse = dets:lookup(records_db, RecId1),
            Result = case DBResponse of
                [_] ->
                    ok = dets:insert(records_db, {RecId1, NewContent}),
                    ok = dets:sync(records_db),
                    Response = io_lib:format("/get/~s", [RecId1]),
                    Response1 = list_to_binary(Response),
                    {{true, Response1}, Req1, State};
                [] ->
                    {true, Req1, State}
            end,
            ok = dets:close(records_db),
            Result;
        _ ->
            {true, Req, State}
    end.

delete_record_to_json(Req, State) ->
    case cowboy_req:method(Req) of
        <<"POST">> ->
            RecId = cowboy_req:binding(record_id, Req),
            RecId1 = binary_to_list(RecId),
            {ok, Recordfilename} = application:get_env(
                backend, records_file_name),
            {ok, _} = dets:open_file(
                records_db, [{file, Recordfilename}, {type, set}]),
            DBResponse = dets:lookup(records_db, RecId1),
            Result = case DBResponse of
                [_] ->
                    ok = dets:delete(records_db, RecId1),
                    ok = dets:sync(records_db),
                    Response = io_lib:format("/delete/~s", [RecId1]),
                    Response1 = list_to_binary(Response),
                    {{true, Response1}, Req, State};
                [] ->
                    {true, Req, State}
            end,
            ok = dets:close(records_db),
            Result;
        _ ->
            {true, Req, State}
    end.

get_help(Req, State) ->
    {ok, Recordfilename} = application:get_env(backend, records_file_name),
    {ok, Statefilename} = application:get_env(backend, state_file_name),
    Body = "{
    \"/list\": \"return a list of record IDs\",
    \"/get/ID\": \"retrieve a record by its ID\",
    \"/create\": \"create a new record; return its ID\",
    \"/update/ID\": \"update an existing record\",
    \"records_file_name\": \"~s\",
    \"state_file_name\": \"~s\",
}",
    Body1 = io_lib:format(Body, [Recordfilename, Statefilename]),
    {Body1, Req, State}.

get_help_text(Req, State) ->
    {ok, Recordfilename} = application:get_env(backend, records_file_name),
    {ok, Statefilename} = application:get_env(backend, state_file_name),
    Body = "
- list: return a list of record IDs~n
- get:  retrieve a record by its ID~n
- create: create a new record; return its ID~n
- update:  update an existing record~n
- records_file_name: ~s~n
- state_file_name: ~s~n
",
    Body1 = io_lib:format(Body, [Recordfilename, Statefilename]),
    {Body1, Req, State}.

generate_id(State_file_name) ->
    {ok, Statefilename} = application:get_env(backend, State_file_name),
    dets:open_file(state_db, [{file, Statefilename}, {type, set}]),
    Records = dets:lookup(state_db, current_id),
    Response = case Records of
        [{current_id, CurrentId}] ->
            NextId = CurrentId + 1,
            %    CurrentId, NextId]),
            dets:insert(state_db, {current_id, NextId}),
            Id = lists:flatten(io_lib:format("id_~4..0B", [CurrentId])),
            Id;
        [] ->
            error
    end,
    dets:close(state_db),
    Response.