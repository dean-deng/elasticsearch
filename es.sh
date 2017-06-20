#!/bin/sh

# Created by Dean Deng on June 20, 2017

###### OPTIONS ######
#
# -s <subpath> : add subdirectory [OPTARG: file subpath to add, e.g. /index/type/id)]
#
# -g : GET
#
# -p <path> : PUT [OPTARG: file containing the JSON doc to index]
#
# -d : DELETE 
#
# -h : HEAD (checks if doc exists)
# 
# -q <path> : query [OPTARG: file containing the QueryDSL body]
# 
# -l : list all indices
#
### GET options ###
# -m <path> : multiget [OPTARG: file containing docs to get (index, type, id), in JSON format]
#
### PUT options ###
# -a : automatic indexing, i.e. POST 
# -c : create option, fails if already exists 


###### EXAMPLES ######
#
# GET:
#   ./es.sh -g -s /megacorp
#
# MULTIGET: 
#   ./es.sh -g -m es_mget 
# 
# INDEX:
#   ./es.sh -p es_put -s /megacorp/employee/5 
#
# DELETE:
#   ./es.sh -d -s /megacorp/employee/5
# 
# HEAD: 
#   ./es.sh -h -s /megacorp/employee/5
# 
# QUERY:
#   ./es.sh -q es_query -s /megacorp/employee 
#
# REALLY PAINFUL QUERY:
#   ./es.sh -g -s /megacorp/_search?q=last_name%3Asmith+pretty
# 
# LIST ALL INDICES:
#   ./es.sh -l


###### NOTES ######
#
# Argument order doesn't matter, but behavior is undefined for
# placing multiple actions (g,p,d,h,q) on the same command line.
#
# The elasticsearch 'pretty' option is mostly present by default,
# but has to be manually added for simple get requests.

subdir=""
autoindex="false"
create="false"
multiget="false"
urlroot="localhost:9200"

while getopts :s:gm:dp:achq:l opt; do
    case $opt in
        s) 
            subdir=$OPTARG
            ;;
        m)
            multiget="true"
            docs=$OPTARG
            ;;
        a)
            autoindex="true"
            ;;
        c)
            create="true"
            ;;
    esac
done

OPTIND=1

while getopts :s:gm:dp:achq:l opt; do
    case $opt in
        g)
            if ( $multiget )
            then
                docs=`cat $docs`
                len=${#docs}
                if (( $len == 0 ))
                then 
                    echo "Multiget file empty or does not exist"
                    exit 1
                fi
                curl -XGET $urlroot$subdir'/_mget?pretty' -H 'Content-Type: application/json' -d "$docs"
            else 
                curl -XGET $urlroot$subdir
            fi
            ;;
        p)
            data=`cat $OPTARG`
            len=${#data}
            if (( $len == 0 ))
            then 
                echo "Data file empty or does not exist"
                exit 1
            fi
            echo "Data retrieved from $OPTARG \n\n\n"

            if ( $autoindex )
            then
                curl -XPOST $urlroot$subdir'?pretty' -H 'Content-Type: application/json' -d "$data"
            elif ( $create )
            then
                curl -XPUT $urlroot$subdir'/_create?pretty' -H 'Content-Type: application/json' -d "$data"
            else 
                curl -XPUT $urlroot$subdir'?pretty' -H 'Content-Type: application/json' -d "$data"
            fi
            ;;
        d)
            curl -XDELETE $urlroot$subdir'?pretty'
            ;;
        h)
            curl -i -XHEAD $urlroot$subdir'?pretty'
            ;;
        q)
            query=`cat $OPTARG`
            len=${#query}
            if (( $len == 0 ))
            then 
                echo "Query file empty or does not exist"
                exit 1
            fi
            echo "Query retrieved from $OPTARG \n\n\n"
            false=`curl -XGET $urlroot$subdir'/_validate/query?pretty' -H 'Content-Type: application/json' -d "$query" | grep "false" -c`
            if (( $false == 1 ))
            then
                echo "Query invalid\n\n\n"
            else
                curl -XGET $urlroot$subdir'/_search?pretty' -H 'Content-Type: application/json' -d "$query"
            fi
            ;;
        l)
            curl $urlroot'/_cat/indices?v'
            ;;
    esac
done
