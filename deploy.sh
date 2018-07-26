#!/usr/bin/env bash

# https://unix.stackexchange.com/a/197793
args="${@}"

DEBUG=0 # 0 for quiet or 1 to see Docker output

if [ "$DEBUG" -eq "1" ]; then
  OUT='/dev/tty'
else
  OUT='/dev/null'
fi

echo -n 'Building Docker image (this may take a few minutes)...'
./docker_build.sh >$OUT 2>&1
echo 'done.'

echo -n 'Removing old Docker images...'
docker image prune --filter=label=rmdevops -f >$OUT 2>&1
echo 'done.'

docker run \
  --rm \
  --volume ~/.aws:/root/.aws:ro \
  --volume $(pwd):/usr/app \
  --hostname devops-converge \
  --name devops-converge \
  -it devops-converge bundle exec /usr/app/converge.rb $args
