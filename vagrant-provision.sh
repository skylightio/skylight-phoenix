#!/bin/sh

set -e

apt-get update -y
apt-get -f install

# tools for installing stuff
apt-get install -y wget git

# Stuff that phoenix likes
apt-get install -y node npm inotify-tools

# Postgres
apt-get install -y postgresql postgresql-contrib
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"

# Erlang
cd /tmp
wget http://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
dpkg -i erlang-solutions_1.0_all.deb
apt-get update -y
apt-get install -y erlang

# Elixir
wget https://packages.erlang-solutions.com/erlang/elixir/FLAVOUR_2_download/elixir_1.1.1-2~ubuntu~trusty_amd64.deb
dpkg -i elixir_1.1.1-2~ubuntu~trusty_amd64.deb
mix local.hex --force
mix local.rebar --force

# Multirust for Rust (Rust is not installed, but it can easily be installed if
# needed)
cd ~
if [ ! -d ./multirust ]; then
    git clone --recursive https://github.com/brson/multirust && cd multirust
    git submodule update --init
    ./build.sh && ./install.sh
fi

# Dev facilities
apt-get install -y htop
echo "alias l='ls -la'" >> ~/.bash_aliases
