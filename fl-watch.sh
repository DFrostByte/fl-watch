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
	echo "$_SCRIPT: $@" >&2
}

function _err
{
	echo "Error: $_SCRIPT: $@" >&2
}

function _die
{
	_err "$@"
	exit 1
}

function _validate_file_access
# @desc:         Test that the file exists, is readable, writeable and isn't empty.
#                If validation fails, exit with error message.
# @param $1:     Filename.
# @param $2 ...: File tests (f r w s)
# @return:       True if valid. Aborts if fails.
{
	local filename="$1"

	[ -z "$2" ] && _die "$LINENO: No test parameters given."

	while [ -n "$2" ]
	do
		shift 1

		case "$1" in
			'f')
				if   ! [ -f "$filename" ]
				then
					_die "$LINENO: Not a file '$filename'"
				fi
			;;
			'r')
				if ! [ -r "$filename" ]
				then
					_die "$LINENO: Not readable '$filename'"
				fi
			;;
			'w')
				if ! [ -w "$filename" ]
				then
					_die "$LINENO: Not writeable '$filename'"
				fi
			;;
			's')
				if ! [ -s "$filename" ]
				then
					_die "$LINENO: Empty '$filename'"
				fi
			;;
			*)
				_die "$LINENO: Invalid function parameter."
			;;
		esac
	done

	return true
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

#------------------------------------------------------------------------------
# validation
#------------------------------------------------------------------------------

_validate_file_access "$_playlist_filename" f r w s

# read unwatched (not commented) filenames into array
IFS=$'\n'
_unwatched_filenames=(`cat "$_playlist_filename" | grep --invert-match '#'`)
_unwatched_num=${#_unwatched_filenames[@]}

if [ $_unwatched_num -lt 1 ]
then
	# nothing unwatched
	_log "No unwatched files found in playlist."
	exit 0
fi

# make sure unwatched files are readable and not empty
for (( i=0; $i < _unwatched_num; i++ ))
do
	_validate_file_access "${_unwatched_filenames[$i]}" f r s
done

#------------------------------------------------------------------------------
# play
#------------------------------------------------------------------------------

# main loop: play files one at a time, checking them off after playing
for (( i=0; $i < _unwatched_num; i++ ))
do
	unwatched_file="${_unwatched_filenames[$i]}"

	_log "Current file: $unwatched_file"

	if _play "$unwatched_file"
	then
		_mark_watched "$_playlist_filename" "$unwatched_file" || _die "$LINENO: Mark as watched failed."
	else
		# play failed.
		# viewing may have been aborted or a player error occurred so exit
		_log "$LINENO: Exit status of player wasn't success."
		break
	fi
done

exit 0

