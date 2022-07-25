#!/bin/bash

# turn off all docker containers (to stop grafana monitoring)
docker kill $(docker ps -q)