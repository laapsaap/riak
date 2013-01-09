#!/bin/sh

subcommand_usage() {
    echo "Usage: $SCRIPT admin { cluster | join | leave | backup | restore | test | "
    echo "                    reip | js-reload | erl-reload | wait-for-service | "
    echo "                    ringready | transfers | force-remove | down | "
    echo "                    cluster-info | member-status | ring-status | vnode-status |"
    echo "                    aae-status | diag | status | transfer-limit }"
}


cluster_admin()
{
    case "$1" in
        join)
            if [ $# -ne 2 ]; then
                echo "Usage: $SCRIPT cluster join <node>"
                exit 1
            fi
            node_up_check
            $NODETOOL rpc riak_kv_console staged_join "$2"
            ;;
        leave)
            if [ $# -eq 1 ]; then
                node_up_check
                $NODETOOL rpc riak_core_console stage_leave
            elif [ $# -eq 2 ]; then
                node_up_check
                $NODETOOL rpc riak_core_console stage_leave "$2"
            else
                echo "Usage: $SCRIPT cluster leave [<node>]"
                exit 1
            fi
            ;;
        force-remove)
            if [ $# -ne 2 ]; then
                echo "Usage: $SCRIPT cluster force-remove <node>"
                exit 1
            fi
            node_up_check
            $NODETOOL rpc riak_core_console stage_remove "$2"
            ;;
        replace)
            if [ $# -ne 3 ]; then
                echo "Usage: $SCRIPT cluster replace <node1> <node2>"
                exit 1
            fi
            node_up_check
            $NODETOOL rpc riak_core_console stage_replace "$2" "$3"
            ;;
        force-replace)
            if [ $# -ne 3 ]; then
                echo "Usage: $SCRIPT cluster force-replace <node1> <node2>"
                exit 1
            fi
            node_up_check
            $NODETOOL rpc riak_core_console stage_force_replace "$2" "$3"
            ;;
        plan)
            node_up_check
            $NODETOOL rpc riak_core_console print_staged
            ;;
        commit)
            node_up_check
            $NODETOOL rpc riak_core_console commit_staged
            ;;
        clear)
            node_up_check
            $NODETOOL rpc riak_core_console clear_staged
            ;;
        *)
            echo "\
Usage: $SCRIPT cluster <command>

The following commands stage changes to cluster membership. These commands
do not take effect immediately. After staging a set of changes, the staged
plan must be committed to take effect:

   join <node>                    Join node to the cluster containing <node>
   leave                          Have this node leave the cluster and shutdown
   leave <node>                   Have <node> leave the cluster and shutdown

   force-remove <node>            Remove <node> from the cluster without
                                  first handing off data. Designed for
                                  crashed, unrecoverable nodes

   replace <node1> <node2>        Have <node1> transfer all data to <node2>,
                                  and then leave the cluster and shutdown

   force-replace <node1> <node2>  Reassign all partitions owned by <node1> to
                                  <node2> without first handing off data, and
                                  remove <node1> from the cluster.

Staging commands:
   plan                           Display the staged changes to the cluster
   commit                         Commit the staged changes
   clear                          Clear the staged changes
"
    esac
}

subcommand() {
    # Check the first argument for instructions
    if [ "$1" = "admin" ]; then
        shift
        case "$1" in
            join)
                if [ "$2" != "-f" ]; then
                    echo "The 'join' command has been deprecated in favor of the new "
                    echo "clustering commands provided by '$SCRIPT cluster'. To continue "
                    echo "using the deprecated 'join' command, use 'join -f'"
                    exit 1
                fi

                if [ $# -ne 3 ]; then
                    echo "Usage: $SCRIPT join -f <node>"
                    exit 1
                fi

                # Make sure the local node IS running
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi

                $NODETOOL rpc riak_kv_console join "$3"
                ;;

            leave)
                if [ "$2" != "-f" ]; then
                    echo "The 'leave' command has been deprecated in favor of the new "
                    echo "clustering commands provided by '$SCRIPT cluster'. To continue "
                    echo "using the deprecated 'leave' command, use 'leave -f'"
                    exit 1
                fi

                if [ $# -ne 2 ]; then
                    echo "Usage: $SCRIPT leave -f"
                    exit 1
                fi

                # Make sure the local node is running
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi

                $NODETOOL rpc riak_kv_console leave
                ;;

            remove)
                echo "The 'remove' command no longer exists. If you want a node to"
                echo "safely leave the cluster (handoff its data before exiting),"
                echo "then execute 'leave' on the desired node. If a node is down and"
                echo "unrecoverable (and therefore cannot be safely removed), then"
                echo "use the 'force-remove' command. A force removal drops all data"
                echo "owned by the removed node. Read-repair can be used to restore"
                echo "lost replicas."
                exit 1
                ;;

            force[_-]remove)
                if [ "$2" != "-f" ]; then
                    echo "The 'force-remove' command has been deprecated in favor of the new "
                    echo "clustering commands provided by '$SCRIPT cluster'. To continue "
                    echo "using the deprecated 'force-remove' command, use 'force-remove -f'"
                    exit 1
                fi

                if [ $# -ne 3 ]; then
                    echo "Usage: $SCRIPT force-remove -f <node>"
                    exit 1
                fi

                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi

                $NODETOOL rpc riak_kv_console remove "$3"
                ;;

            down)
                if [ $# -ne 2 ]; then
                    echo "Usage: $SCRIPT down <node>"
                    exit 1
                fi

                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi

                shift
                $NODETOOL rpc riak_kv_console down $@
                ;;

            status)
                if [ $# -ne 1 ]; then
                    echo "Usage: $SCRIPT status"
                    exit 1
                fi

                # Make sure the local node IS running
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi
                shift

                $NODETOOL rpc riak_kv_console status $@
                ;;

            vnode[_-]status)
                if [ $# -ne 1 ]; then
                    echo "Usage: $SCRIPT $1"
                    exit 1
                fi

                # Make sure the local node IS running
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi
                shift

                $NODETOOL rpc riak_kv_console vnode_status $@
                ;;

            ringready)
                if [ $# -ne 1 ]; then
                    echo "Usage: $SCRIPT ringready"
                    exit 1
                fi

                # Make sure the local node IS running
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi
                shift

                $NODETOOL rpc riak_kv_console ringready $@
                ;;

            transfers)
                if [ $# -ne 1 ]; then
                    echo "Usage: $SCRIPT transfers"
                    exit 1
                fi

                # Make sure the local node IS running
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi
                shift

                $NODETOOL rpc riak_kv_console transfers $@
                ;;

            member[_-]status)
                if [ $# -ne 1 ]; then
                    echo "Usage: $SCRIPT $1"
                    exit 1
                fi

                # Make sure the local node IS running
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi
                shift

                $NODETOOL rpc riak_core_console member_status $@
                ;;

            ring[_-]status)
                if [ $# -ne 1 ]; then
                    echo "Usage: $SCRIPT $1"
                    exit 1
                fi

                # Make sure the local node IS running
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi
                shift

                $NODETOOL rpc riak_core_console ring_status $@
                ;;

            aae[_-]status)
                if [ $# -ne 1 ]; then
                    echo "Usage: $SCRIPT $1"
                    exit 1
                fi
                shift

                node_up_check
                $NODETOOL rpc riak_kv_console aae_status $@
                ;;

            cluster[_-]info)
                if [ $# -lt 2 ]; then
                    echo "Usage: $SCRIPT $1 <output_file> ['local' | <node> ['local' | <node>] [...]]"
                    exit 1
                fi

                # Make sure the local node IS running
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi
                shift

                $NODETOOL rpc_infinity riak_kv_console cluster_info $@
                ;;

            services)
                $NODETOOL rpcterms riak_core_node_watcher services ''
                ;;

            wait[_-]for[_-]service)
                SVC=$2
                TARGETNODE=$3
                if [ $# -lt 3 ]; then
                    echo "Usage: $SCRIPT $1 <service_name> <target_node>"
                    exit 1
                fi

                while (true); do
                    # Make sure riak_core_node_watcher is up and running locally before trying to query it
                    # to avoid ugly (but harmless) error messages
                    NODEWATCHER=`$NODETOOL rpcterms erlang whereis "'riak_core_node_watcher'."`
                    if [ "$NODEWATCHER" = "undefined" ]; then
                        echo "$SVC is not up: node watcher is not running"
                        continue
                    fi

                    # Get the list of services that are available on the requested noe
                    SERVICES=`$NODETOOL rpcterms riak_core_node_watcher services "'${TARGETNODE}'."`
                    echo "$SERVICES" | grep "[[,]$SVC[],]" > /dev/null 2>&1
                    if [ "X$?" = "X0" ]; then
                        echo "$SVC is up"
                        exit 0
                    else
                        echo "$SVC is not up: $SERVICES"
                    fi
                    sleep 3
                done
                ;;

            js[_-]reload)
                # Reload all Javascript VMs
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi

                shift #optional names come after 'js_reload'
                $NODETOOL rpc riak_kv_js_manager reload $@
                ;;

            erl[_-]reload)
                # Reload user Erlang code
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi

                $NODETOOL rpc riak_kv_console reload_code
                ;;

            reip)
                ACTION=$1
                shift
                if [ $# -lt 2 ]; then
                    echo "Usage $SCRIPT $ACTION <old_nodename> <new_nodename>"
                    exit 1
                fi
                # Make sure the local node IS not running
                RES=`$NODETOOL ping`
                if [ "$RES" = "pong" ]; then
                    echo "Node must be down to re-ip."
                    exit 1
                fi
                OLDNODE=$1
                NEWNODE=$2
                $ERTS_PATH/erl -noshell \
                    -pa $RUNNER_LIB_DIR/basho-patches \
                    -config $RUNNER_ETC_DIR/app.config \
                    -eval "riak_kv_console:$ACTION(['$OLDNODE', '$NEWNODE'])" \
                    -s init stop
                ;;

            restore)
                ACTION=$1
                shift

                if [ $# -lt 3 ]; then
                    echo "Usage: $SCRIPT $ACTION <node> <cookie> <filename>"
                    exit 1
                fi

                NODE=$1
                COOKIE=$2
                FILENAME=$3

                $ERTS_PATH/erl -noshell $NAME_PARAM riak_kv_backup$NAME_HOST -setcookie $COOKIE \
                            -pa $RUNNER_LIB_DIR/basho-patches \
                            -eval "riak_kv_backup:$ACTION('$NODE', \"$FILENAME\")" -s init stop
                ;;

            backup)
                ACTION=$1
                shift

                if [ $# -lt 4 ]; then
                    echo "Usage: $SCRIPT $ACTION <node> <cookie> <filename> [node|all]"
                    exit 1
                fi

                NODE=$1
                COOKIE=$2
                FILENAME=$3
                TYPE=$4

                $ERTS_PATH/erl -noshell $NAME_PARAM riak_kv_backup$NAME_HOST -setcookie $COOKIE \
                            -pa $RUNNER_LIB_DIR/basho-patches \
                            -eval "riak_kv_backup:$ACTION('$NODE', \"$FILENAME\", \"$TYPE\")" -s init stop
                ;;

            test)
                # Make sure the local node IS running
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi

                shift

                # Parse out the node name to pass to the client
                NODE_NAME=${NAME_ARG#* }

                $ERTS_PATH/erl -noshell $NAME_PARAM riak_test$NAME_HOST $COOKIE_ARG \
                            -pa $RUNNER_LIB_DIR/basho-patches \
                            -eval "case catch(riak:client_test(\"$NODE_NAME\")) of \
                                    ok -> init:stop();                             \
                                    _  -> init:stop(1)                             \
                                    end."

                ;;
            diag)
                # Riaknostic location
                RIAKNOSTIC_LOC="$ERTS_PATH/../../lib/riaknostic/riaknostic"

                # Riaknostic user
                RIAKNOSTIC_USER=$RUNNER_USER
                if [ -z $RUNNER_USER ]; then
                    RIAKNOSTIC_USER=$LOGNAME
                fi

                # Setup command to run riaknostic
                RIAKNOSTIC="$ERTS_PATH/escript $RIAKNOSTIC_LOC --user $RIAKNOSTIC_USER \
                    --etc $RUNNER_ETC_DIR --base $RUNNER_BASE_DIR"

                # URL for Riaknostic download instructions
                RIAKNOSTIC_URL="http://riaknostic.basho.com/"

                shift

                if [ -f "$RIAKNOSTIC_LOC" ]; then
                    $RIAKNOSTIC "$@"
                else
                    echo "Riak diagnostics utility is not present!"
                    echo "Visit $RIAKNOSTIC_URL for instructions."
                    exit 1
                fi

                ;;
            top)
                # Make sure the local node IS running
                RES=`$NODETOOL ping`
                if [ "$RES" != "pong" ]; then
                    echo "Node is not running!"
                    exit 1
                fi
                shift

                MYPID=$$
                NODE_NAME=${NAME_ARG#* }
                $ERTS_PATH/erl -noshell -noinput \
                    -pa $RUNNER_LIB_DIR/basho-patches \
                    -hidden $NAME_PARAM riak_etop$MYPID$NAME_HOST $COOKIE_ARG \
                    -s etop -s erlang halt -output text \
                    -node $NODE_NAME \
                    $* -tracing off
                ;;
            cluster)
                shift
                cluster_admin "$@"
                ;;
            transfer[_-]limit)
                if [ $# -gt 3 ]; then
                    echo "Usage: $SCRIPT $1"
                    echo "       $SCRIPT $1 <limit>"
                    echo "       $SCRIPT $1 <node> <limit>"
                    exit
                fi
                node_up_check
                shift
                $NODETOOL rpc riak_core_console transfer_limit "$@"
                ;;
            *)
                subcommand_usage
                exit 1
                ;;
        esac
    else 
        echo "$1"
        # print the toplevel usage
        main_usage
        exit 1
    fi
}
