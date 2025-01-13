#!/usr/bin/env zsh

run_remote() {
    rm -rf ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote
    cp -r remote ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote
    open -a "Ableton Live 12 Suite"

    until [ -f ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote/logs/remote.log ]; do 
        sleep 1
    done
    tail -f ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote/logs/remote.log
}

send_packet() {
    shift
    echo "$@" | nc -u -w 0 0.0.0.0 42069
}

ableton_logs() {
    tail -f ~/Library/Preferences/Ableton/Live\ 12.1.5/Log.txt
}

remote_logs() {
    less ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote/logs/remote.log
}

case "$1" in
    "send")
        send_packet "$@"
        ;;
    "ableton_logs")
        ableton_logs
        ;;
    "remote_logs")
        remote_logs
        ;;
    *)
        run_remote
        ;;
esac
