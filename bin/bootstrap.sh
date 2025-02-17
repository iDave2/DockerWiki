#!/usr/bin/env bash
#
#  To get things rolling. Variable definition precedence, hi to lo,
#  is command-line, then user config, and finally the .env defaults.
#
#  Also see:
#    * https://stackoverflow.com/a/246128.
#
####-####+####-####+####-####+####-####+####-####+####-####+####-####+####

set -uo pipefail # pipe status is last-to-fail or zero if none fail

ScriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

UserConfig=$(source "${ScriptDir}/../.env" && echo $DW_USER_CONFIG)
test -f "$UserConfig" && source "$UserConfig"

source "${ScriptDir}/../.env" # second pass, also quick

source "${ScriptDir}/include.sh"
