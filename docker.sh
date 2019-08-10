#!/bin/bash

docker build --tag valhalla .

docker rm -f val || true

docker run --restart always -d --dns 127.0.0.1 --hostname valhalla --name val -p 127.0.0.1:53:5353/udp valhalla:latest

#winpty docker exec -it val bash
docker logs val -f