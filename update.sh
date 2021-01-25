#!/bin/bash

git submodule init
git submodule update --remote --merge

docker-compose pull
