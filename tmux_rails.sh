#!/bin/bash
CURRENT_SESSION=${PWD##*/}

# Do we have Rakefile in the directory?
# if [ ! -f Rakefile ]
#then
#	  echo "Rakefile not found in current directory"
#	    exit 1;
#    fi
#
#    # Make sure there is a task to start up the server
#    if ! grep -q "task :server" Rakefile
#    then
#	      echo "No server task found in Rakefile"
#	        exit 1;
#	fi

# Start up the tmux session with specific name
tmux new-session -d -s $CURRENT_SESSION

# VIM window
tmux rename-window -t $CURRENT_SESSION:1 proj 

tmux split-window -h

# With pane numbering starting at 1
tmux split-window -h
tmux select-pane -t 1 
tmux resize-pane -L 20
# tmux send-keys 'bundle exec rails c' 'C-m'

tmux select-pane -t 3
tmux split-window -v

# Window for running development server
tmux new-window
tmux rename-window server
tmux send-keys 'postgres -D /usr/local/var/postgres'
# tmux send-keys 'bundle exec rake sunspot:start' 'C-m'
# tmux send-keys 'bundle exec rails s -b 0.0.0.0' 'C-m'

open -a "Google Chrome" --args 'http://127.0.0.1:3000' 'https://plus.google.com/hangouts'
# open -a "Github Desktop"
open -a "Slack"

# Window for logs
#tmux new-window -t $CURRENT_SESSION -a -n logs

# Select the first window
tmux select-window -t proj

# Attach the tmux session
tmux attach -t $CURRENT_SESSION
