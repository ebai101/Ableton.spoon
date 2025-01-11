#!/usr/bin/env zsh

rm -rf ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote
cp -r remote ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote
open -a "Ableton Live 12 Suite"

until [ -f ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote/logs/remote.log ]; do 
    sleep 1
done
tail -f ~/Music/Ableton/User\ Library/Remote\ Scripts/AAAremote/logs/remote.log
# tail -f ~/Library/Preferences/Ableton/Live\ 12.1.5/Log.txt
