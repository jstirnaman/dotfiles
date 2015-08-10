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
	tmux rename-window -t $CURRENT_SESSION:1 vim
	tmux split-window -h
	tmux select-pane -t 0
	tmux resize-pane -R 20
	tmux send-keys 'vim' 'C-m'

        tmux select-pane -t 1
        tmux split-window -v
	tmux select-pane -t 2
	tmux send-keys 'pry' 'C-m'
        tmux select-pane -t 0
	# Window for running development server
	tmux new-window
	tmux rename-window server
	tmux send-keys 'bundle exec rake sunspot:start' 'C-m'
	tmux send-keys 'bundle exec rails s' 'C-m'

	open -a "Google Chrome" --args 'http://127.0.0.1:3000'
	open -a "Github"
	open -a "Slack"
        
	# Window for logs
        tmux new-window -t $CURRENT_SESSION -a -n logs
        tmux split-window -v
        tmux select-pane -t 0
	# Select the first window
	tmux select-window -t 0

	# Attach the tmux session
	tmux attach -t $CURRENT_SESSION
