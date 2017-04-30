#!/bin/bash

# can do installs or updates
# expected to run in a repository that is git-updated
# run as ./install.sh 

# essentially: here
srcroot=$(pwd -P)

# where all the data lies; may provisions were made in the code to
# have this configurable (in the django settings)
# but there might still be other places where it's hard-wired
# so it's safer to use this for now
root=/nbhosting

function check-subdirs() {
    for subdir in jupyter courses-git logs; do
	[ -d $root/$subdir ] || mkdir -p $root/$subdir
    done
}

# rsync options
rsopts=-rltpv

# create the /var/log/nbhosting symlink
function log-symlink() {
    local varlink=/var/log/nbhosting
    [ -h $varlink ] || ln -sf $root/logs $varlink
}

function update-python-libraries() {
    ./setup.py install
}

function update-bins() {
    rsync $rsopts scripts/nbh-* /usr/bin
}

function update-jupyter() {
    mkdir -p $root/jupyter
    rsync $rsopts jupyter/ $root/jupyter/
}

function update-uwsgi() {
    sed -e "s,@DJANGO-ROOT@,$srcroot/nbhosting," uwsgi/nbhosting.ini.in > uwsgi/nbhosting.ini
    rsync $rsopts  uwsgi/nbhosting.ini /etc/uwsgi.d/
}

function update-nginx() {
    rsync $rsopts nginx/nginx.conf /etc/nginx/
    rsync $rsopts nginx/nbhosting.conf /etc/nginx/conf.d/
}
    
function restart-services() {
    rsync $rsopts systemd/nbh-uwsgi.service /etc/systemd/system/
    rsync $rsopts systemd/nbh-monitor.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl restart nginx
    systemctl restart nbh-uwsgi
    systemctl restart nbh-monitor
}

function default-main() {
    check-subdirs

    update-python-libraries
    update-bins
    update-jupyter

    update-uwsgi
    update-nginx
    restart-services

    # this is just convenience
    log-symlink
}

# with no argument we run default-main
# otherwise one can invoke one or several steps
# with e.g. install.sh update-uwsgi log-symlink
function main() {
    if [[ -z "$@" ]]; then
	default-main
    else
	for command in "$@"; do $command; done
    fi
}

main "$@"
