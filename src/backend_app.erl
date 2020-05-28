-module(backend_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

start(_Type, _Args) ->
	Dispatch = cowboy_router:compile([
        {'_', [
               {"/list", toppage_h, [list]},
               {"/get/:record_id", toppage_h, [get]},
               {"/get_user/:record_id", toppage_h, [get_user]},
               {"/get_user_by_name/:user_name", toppage_h, [get_user_by_name]},
               {"/get_all_users", toppage_h, [get_all_users]},
               {"/get_conversation/:record_id", toppage_h, [get_conversation]},
               {"/get_conversations_by_user/:user_name", toppage_h, [get_conversations_by_user]},
               {"/get_message/:record_id", toppage_h, [get_message]},
               {"/get_messages_by_conv/:conv_id", toppage_h, [get_messages_by_conv]},
               {"/create_user", toppage_h, [create_user]},
               {"/create_conversation", toppage_h, [create_conversation]},
               {"/create_message", toppage_h, [create_message]},
               {"/update/:record_id", toppage_h, [update]},
               {"/delete/:record_id", toppage_h, [delete]},
               {"/help", toppage_h, [help]},
               {"/", toppage_h, [help]}
              ]}
    ]),
    {ok, _} = cowboy:start_clear(my_http_listener,
        	[{port, 80}],
        	#{env => #{dispatch => Dispatch}}
    ),
	backend_sup:start_link().

stop(_State) ->
	ok.
