%%%-----------------------------------------------------------------------------
%%% Copyright (c) 2015-2017 Feng Lee <feng@emqtt.io>. All Rights Reserved.
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in all
%%% copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%%% SOFTWARE.
%%%-----------------------------------------------------------------------------
%%% @doc ecpool worker.
%%%
%%% @author Feng Lee <feng@emqtt.io>
%%%-----------------------------------------------------------------------------

-module(ecpool_worker).

-behaviour(gen_server).

%% API Function Exports
-export([start_link/4, client/1, is_connected/1]).

%% gen_server Function Exports
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {pool, id, client, mod, opts}).

%%%=============================================================================
%%% Callback
%%%=============================================================================

-ifdef(use_specs).

-callback connect(ConnOpts :: list()) -> {ok, pid()} | {error, any()}.

-else.

-export([behaviour_info/1]).

behaviour_info(callbacks) ->
    [{connect, 1}];

behaviour_info(_Other) ->
    undefined.

-endif.

%%%=============================================================================
%%% API
%%%=============================================================================

%% @doc Start the pool worker.
-spec start_link(atom(), pos_integer(), module(), list()) ->
    {ok, pid()} | ignore | {error, any()}.
start_link(Pool, Id, Mod, Opts) ->
    gen_server:start_link(?MODULE, [Pool, Id, Mod, Opts], []).

%% @doc Get client/connection.
-spec client(Worker :: pid()) -> {ok, pid()} | {error, not_connected}.
client(Pid) ->
    gen_server:call(Pid, client, infinity).

%% @doc Is client connected?
-spec is_connected(pid()) -> boolean().
is_connected(Pid) ->
    gen_server:call(Pid, is_connected).

%%%=============================================================================
%%% gen_server callbacks
%%%=============================================================================

init([Pool, Id, Mod, Opts]) ->
    process_flag(trap_exit, true),
    State = #state{pool = Pool, id = Id, mod = Mod, opts = Opts},
    case connect(State) of
        {ok, Client} ->
            gproc_pool:connect_worker(ecpool:name(Pool), {Pool, Id}),
            {ok, State#state{client = Client}};
        {error, Error} ->
            {stop, Error}
    end.

handle_call(is_connected, _From, State = #state{client = Client}) ->
    {reply, Client =/= undefined andalso is_process_alive(Client), State};

handle_call(client, _From, State = #state{client = undefined}) ->
    {reply, {error, not_connected}, State};

handle_call(client, _From, State = #state{client = Client}) ->
    {reply, {ok, Client}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({'EXIT', Pid, Reason}, State = #state{client = Pid, opts = Opts}) ->
    case proplists:get_value(auto_reconnect, Opts, false) of
        false ->
            {stop, Reason, State};
        Secs ->
            reconnect(Secs, State)
    end;

handle_info(reconnect, State = #state{opts = Opts}) ->
    case connect(State) of
        {ok, Client} ->
            {noreply, State#state{client = Client}};
        {error, _Error} ->
            reconnect(proplists:get_value(auto_reconnect, Opts), State)
    end;

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{pool = Pool, id = Id}) ->
    gproc_pool:disconnect_worker(ecpool:name(Pool), {Pool, Id}).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%=============================================================================
%%% Internal Functions
%%%=============================================================================

connect(#state{mod = Mod, opts = Opts}) ->
    Mod:connect(connopts(Opts, [])).

connopts([], Acc) ->
    Acc;
connopts([{pool_size, _} | Opts], Acc) ->
    connopts(Opts, Acc);
connopts([{pool_busy, _} | Opts], Acc) ->
    connopts(Opts, Acc);
connopts([{auto_reconnect, _} | Opts], Acc) ->
    connopts(Opts, Acc);
connopts([Opt | Opts], Acc) ->
    connopts(Opts, [Opt | Acc]).

reconnect(Secs, State) ->
    erlang:send_after(timer:seconds(Secs), self(), reconnect),
    {noreply, State#state{client = undefined}}.

