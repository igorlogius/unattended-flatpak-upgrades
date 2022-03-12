#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# DESCRIPTION: 
# -----------------------------------------------------------------------------
# auto updates flatpak apps which dont have remote permission 
# changes without having to worry about remote permission changes getting 
# deployed without a users knowledge

# -----------------------------------------------------------------------------
# CONFIGURATION PARAMETERS: 
# -----------------------------------------------------------------------------
# SCRIPTNAME=$(basename ${BASH_SOURCE[0]})
SCRIPTNAME=unattended-flatpak-upgrades
LOGDIR=~/.logs

# -----------------------------------------------------------------------------
# TODOS: 
# -----------------------------------------------------------------------------
# - exclude none security relevant parts of the metadata from the comparison 
# - maybe replace crudini with something smaller
# - add notification (for example via notify-send) when available

# -----------------------------------------------------------------------------
# Check dependencies 
# -----------------------------------------------------------------------------

MISSING_BIN=0
for bin in flatpak tail mktemp mkdir crudini tee echo rm basename;do
	type "$bin" >/dev/null 2>&1 || { echo "ERR: missing $bin"; MISSING_BIN=1; }
done
if [ $MISSING_BIN -ne 0 ];then
	echo "ERR: aborting ... "
fi

# -----------------------------------------------------------------------------
# Redirect output to file
# -----------------------------------------------------------------------------

mkdir -p $LOGDIR >/dev/null 2>&1
exec &> >(tee -a $LOGDIR/$SCRIPTNAME)
exec 2>&1

# -----------------------------------------------------------------------------
# M A I N  
# -----------------------------------------------------------------------------

echo "$(date +%F_%R) started"

flatpak list --app --columns=application,origin | tail -n+2 | 
{
    # temp files
    LOCAL=$(mktemp)
    REMOTE=$(mktemp)
    DIFF=$(mktemp)

    while read APPID ORIGIN; do

        # get local and remote meta
        flatpak info -m $APPID > $LOCAL
        flatpak remote-info --show-metadata $ORIGIN $APPID > $REMOTE

        # compare metas
        diff -y -w -B <(crudini --get --format=lines $LOCAL|sort) \
            <(crudini --get --format=lines $REMOTE  | sort) 2>&1 > $DIFF
        RET=$?

        # auto update or delay/notify
        if [ $RET -eq 0 ];then
            #echo "$APPID no change detected ... starting update"
            flatpak update --noninteractive --app $APPID >/dev/null
         else
            cat $DIFF
            echo "$APPID has changes, resolve via 'flatpak update $APPID'"
            # send notification
        fi
    done

    # remove temporary files
    rm -f $LOCAL $REMOTE $DIFF
}
# 
echo "$(date +%F_%R) done"
# -----------------------------------------------------------------------------
# E O F 
# -----------------------------------------------------------------------------
