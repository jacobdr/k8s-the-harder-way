#!/usr/bin/env bash

export LOGGING_PREFIX="k8s"

function _get_script_name() {
    basename "$0"
}

export -f _get_script_name

function log_info() {
    : "${1?-Must supply an message to log as the first parameter}"
    echo >&2 "${LOGGING_PREFIX}::$(_get_script_name)::INFO -- ${1}"
}

export -f log_info

function log_error() {
    : "${1?-Must supply an message to log as the first parameter}"
    echo >&2 "${LOGGING_PREFIX}::$(_get_script_name)::ERROR -- ${1}"
}

export -f log_error

function log_debug() {
    : "${1?-Must supply an message to log as the first parameter}"
    echo >&2 "${LOGGING_PREFIX}::$(_get_script_name)::DEBUG -- ${1}"
}

export -f log_debug
