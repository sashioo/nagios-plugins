#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2016-01-26 23:36:03 +0000 (Tue, 26 Jan 2016)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x

srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir/.."

. "$srcdir/utils.sh"

echo "
# ============================================================================ #
#                            A p a c h e   D r i l l
# ============================================================================ #
"

export APACHE_DRILL_VERSIONS="${@:-${APACHE_DRILL_VERSIONS:-latest 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 1.10}}"

APACHE_DRILL_HOST="${DOCKER_HOST:-${APACHE_DRILL_HOST:-${HOST:-localhost}}}"
APACHE_DRILL_HOST="${APACHE_DRILL_HOST##*/}"
APACHE_DRILL_HOST="${APACHE_DRILL_HOST%%:*}"
export APACHE_DRILL_HOST
export APACHE_DRILL_PORT=8047

export DOCKER_CONTAINER="nagios-plugins-apache-drill"

check_docker_available

print_port_mappings(){
    echo
    echo "Port Mappings for Debugging:"
    echo
    echo "export APACHE_DRILL_PORT=$APACHE_DRILL_PORT"
    echo
}

trap 'result=$?; print_port_mappings; exit $result' $TRAP_SIGNALS

test_drill(){
    local version="$1"
    hr
    echo "Setting up Apache Drill $version test container"
    hr
    #echo "lauching drill container linked to zookeeper"
    #local DOCKER_OPTS="--link $DOCKER_CONTAINER:zookeeper"
    #local DOCKER_CMD="supervisord -n"
    #launch_container "$DOCKER_IMAGE2:$version" "$DOCKER_CONTAINER2" $APACHE_DRILL_PORT
    VERSION="$version" docker-compose up -d
    if [ -n "${NOTESTS:-}" ]; then
        exit 0
    fi
    port="`docker-compose port "$DOCKER_SERVICE" "$APACHE_DRILL_PORT" | sed 's/.*://'`"
    when_ports_available "$startupwait" "$APACHE_DRILL_HOST" "$port"
    if [ "$version" = "latest" ]; then
        local version="*"
    fi
    hr
    set +e
    #found_version="$(docker exec  "$DOCKER_CONTAINER" ls / | grep apache-drill | tee /dev/stderr | tail -n1 | sed 's/-[[:digit:]]*//')"
    env | grep -i -e docker -e compose
    found_version="$(docker-compose exec "$DOCKER_SERVICE" ls / -1 --color=no | grep --color=no apache-drill | tee /dev/stderr | tail -n 1 | sed 's/apache-drill-//')"
    set -e
    if [[ "$found_version" != $version* ]]; then
        echo "Docker container version does not match expected version! (found '$found_version', expected '$version')"
        exit 1
    fi
    hr
    echo "found Apache Drill version $found_version"
    hr
    #./check_apache_drill_version.py -P $port -v -e "$version"
    hr
    ./check_apache_drill_status.py -P $port -v
    hr
    $perl -T ./check_apache_drill_metrics.pl -P $port -v
    hr
    #delete_container "$DOCKER_CONTAINER2"
    docker-compose down
    echo
}

#startupwait 1
#echo "launching zookeeper container"
#launch_container "$DOCKER_IMAGE" "$DOCKER_CONTAINER" 2181 3181 4181

startupwait 30
test_versions="$(ci_sample $APACHE_DRILL_VERSIONS)"
for version in $test_versions; do
    test_drill "$version"
done

if [ -n "${NOTESTS:-}" ]; then
    print_port_mappings
else
    untrap
    echo "All Apache Drill tests succeeded for versions: $test_versions"
fi
echo

#delete_container "$DOCKER_CONTAINER"
echo
