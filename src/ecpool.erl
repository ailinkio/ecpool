%%%-----------------------------------------------------------------------------
%%% Copyright (c) 2015-2016 Feng Lee <feng@emqtt.io>. All Rights Reserved.
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
%%% @doc ecpool Main API.
%%%
%%% @author Feng Lee <feng@emqtt.io>
%%%-----------------------------------------------------------------------------

-module(ecpool).

%% API Exports
-export([name/1, pool_spec/4, start_pool/3, start_sup_pool/3, stop_sup_pool/1,
         with_client/2, workers/1]).

-type option() :: {pool_size, pos_integer()}
                | {pool_busy, nowait | {wait, pos_integer()}}
                | {auto_reconnect, false | pos_integer()}
                | proplists:proplist().

%% @doc ecpool name
name(Pool) -> {?MODULE, Pool}.

%% @doc Pool ChildSpec
pool_spec(ChildId, Pool, Mod, Opts) ->
    {ChildId, {?MODULE, start_pool, [Pool, Mod, Opts]},
        permanent, 5000, supervisor, [ecpool_pool_sup]}.

%% @doc Start the pool
-spec start_pool(atom(), atom(), [option()]) -> {ok, pid()} | {error, any()}.
start_pool(Pool, Mod, Opts) when is_atom(Pool) ->
    ecpool_pool_sup:start_link(Pool, Mod, Opts).

%% @doc Start the pool supervised by ecpool_sup
start_sup_pool(Pool, Mod, Opts) when is_atom(Pool) ->
    ecpool_sup:start_pool(Pool, Mod, Opts).

%% @doc Start the pool supervised by ecpool_sup
stop_sup_pool(Pool) when is_atom(Pool) ->
    ecpool_sup:stop_pool(Pool).

%% @doc Call the fun with client/connection
-spec with_client(atom(), fun((Client :: pid()) -> any())) -> any().
with_client(Pool, Fun) when is_atom(Pool) ->
    case gproc_pool:claim(name(Pool), fun(_, Pid) -> with_worker(Pid, Fun) end,
                          ecpool_pool:busy_wait(Pool)) of
        {true, Res} -> Res;
        false       -> {error, pool_busy}
    end.

%% @private
with_worker(WorkerPid, Fun) ->
    case ecpool_worker:client(WorkerPid) of
        {ok, Client}    -> Fun(Client);
        Error           -> Error
    end.

%% @doc pool workers
workers(Pool) ->
    gproc_pool:active_workers(name(Pool)).

