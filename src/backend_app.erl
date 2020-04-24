-module(backend_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

start(_Type, _Args) ->
	Dispatch = cowboy_router:compile([
        {'_', [
               {"/list", toppage_h, [list]},
               {"/get/:record_id", toppage_h, [get]},
               {"/create", toppage_h, [create]},
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
