#!/usr/bin/env zsh

trap kill_ableton INT

run_remote() {
    rm -rf ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote
    cp -r remote ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote
    open -a "Ableton Live 12 Suite"
}

send_packet() {
    shift
    echo "$@" | nc -u -w 0 0.0.0.0 42069
}

tail_ableton_log() {
    tail -f ~/Library/Preferences/Ableton/Live\ 12.1.5/Log.txt
}

tail_remote_log() {
    until [ -f ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote/logs/remote.log ]; do 
        sleep 1
    done
    tail -f ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote/logs/remote.log
}

less_ableton_log() {
    less ~/Library/Preferences/Ableton/Live\ 12.1.5/Log.txt
}

less_remote_log() {
    less ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote/logs/remote.log
}

kill_ableton() {
    osascript -e 'tell application "Live" to quit'
}

case "$1" in
    "send")
        send_packet "$@"
        ;;
    "ableton_log")
        less_ableton_log
        ;;
    "remote_log")
        less_remote_log
        ;;
    "remote")
        run_remote
        tail_remote_log
        ;;
    "ableton")
        run_remote
        tail_ableton_log
        ;;
    *)
        echo "options: send, ableton_log, remote_log, remote, ableton"
        ;;
esac
