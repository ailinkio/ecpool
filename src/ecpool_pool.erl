%%--------------------------------------------------------------------
%% Copyright (c) 2013-2017 EMQ Enterprise, Inc. (http://emqtt.io)
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------
%%
%% @doc Wrap gproc_pool.
%%
%%--------------------------------------------------------------------

-module(ecpool_pool).

-author("Feng Lee <feng@emqtt.io>").

-behaviour(gen_server).

-import(proplists, [get_value/3]).

%% API Function Exports
-export([start_link/2, info/1]).

%% gen_server Function Exports
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {name, size, type}).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------

start_link(PoolId, Opts) ->
    gen_server:start_link(?MODULE, [PoolId, Opts], []).

info(Pid) ->
    gen_server:call(Pid, info).

%%--------------------------------------------------------------------
%% gen_server callbacks
%%--------------------------------------------------------------------

init([PoolId, Opts]) ->
    Schedulers = erlang:system_info(schedulers),
    PoolSize = get_value(pool_size, Opts, Schedulers),
    PoolType = get_value(pool_type, Opts, random),
    ensure_pool(ecpool:name(PoolId), PoolType, [{size, PoolSize}]),
    lists:foreach(fun(I) ->
            ensure_pool_worker(ecpool:name(PoolId), {PoolId, I}, I)
        end, lists:seq(1, PoolSize)),
    {ok, #state{name = PoolId, size = PoolSize, type = PoolType}}.

ensure_pool(PoolId, Type, Opts) ->
    try gproc_pool:new(PoolId, Type, Opts)
    catch
        error:exists -> ok
    end.

ensure_pool_worker(PoolId, Name, Slot) ->
    try gproc_pool:add_worker(PoolId, Name, Slot)
    catch
        error:exists -> ok
    end.

handle_call(info, _From, State = #state{name = PoolId, size = Size, type = Type}) ->
    Info = [{pool_id, PoolId},
            {pool_size, Size},
            {pool_type, Type},
            {workers, ecpool:workers(PoolId)}],
    {reply, Info, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unexpected_req}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{name = PoolId, size = Size}) ->
    lists:foreach(fun(I) ->
                gproc_pool:remove_worker(ecpool:name(PoolId), {PoolId, I})
        end, lists:seq(1, Size)),
    gproc_pool:delete(ecpool:name(PoolId)).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

