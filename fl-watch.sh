#!/bin/bash

###############################################################################
# @PROGRAM: fl-watch.sh
###############################################################################
# @DESC:
# + read files to play from a saved list, skipping commented lines '#'
# + find next file to watch (first uncommented line)
# + play that file
# + comment that file out of the playlist with a date and time stamp
# @PARAM 1: Playlist filename
###############################################################################

###############################################################################
# GLOBALS
###############################################################################

_SCRIPT="$0"

_playlist_filename=''


###############################################################################
# FUNCTIONS
###############################################################################

#------------------------------------------------------------------------------
# error / log
#------------------------------------------------------------------------------

function _log
{
	echo "$_SCRIPT: $@" 1>&2
}

function _err
{
	echo "Error: $_SCRIPT: $@" 1>&2
}

function _die
{
	_err "$@"
	exit 1
}

#------------------------------------------------------------------------------

function _mark_watched
# @desc:     Mark a filename as watched by commenting it out with a timestamp
#            in it's playlist file.
# @param $1: Playlist filename.
# @param $2: Watched item filename.
# @return:   Success of marking
{
	local playlist="$1"
	local watched="$2"

	local timestamp="$(date '+%Y-%m-%d-%H:%M')"
	local playlist_num="$(grep --line-number --max-count=1 "$watched" "$playlist" | cut -d':' -f1)"

	[ -z "$playlist_num" ] && return false

	sed -i "$playlist_num s=^=#$timestamp =" "$playlist"
}

function _play
# @desc:     Play (watch) a given file
# @param $1: Filename of item to play
# @return:   Exit status of player
{
	local file="$1"

	mplayer -fs "$file"
}

###############################################################################
# MAIN
###############################################################################

_playlist_filename="$1"

# read unwatched (not commented) filenames into array
IFS=$'\n'
_unwatched_filenames=(`cat "$_playlist_filename" | grep --invert-match '#'`)

# main loop: play files one at a time, checking them off after playing
for (( i=0; $i < ${#_unwatched_filenames[@]}; i++ ))
do
	unwatched_file="${_unwatched_filenames[$i]}"

	_log "Current file: $unwatched_file"

	if _play "$unwatched_file"
	then
		_mark_watched "$_playlist_filename" "$unwatched_file" || _die "$LINENO: Mark as watched failed."
	else
		# viewing may have been aborted or a player error occurred so end
		_log "$LINENO: Exit status of player wasn't success."
		break
	fi
done

exit 0

