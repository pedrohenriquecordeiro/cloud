#!/bin/sh
export $(grep -v '^#' /app/.env | xargs)
exec "$@"
