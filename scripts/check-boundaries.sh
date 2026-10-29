#!/usr/bin/env bash
# Audits the module rules. Package.swift already makes forbidden imports a compile error; this
# catches someone loosening Package.swift to "fix" one. Exits non-zero on any violation.
#
#   NavigationCore          imports nothing from this package
#   <X>NavigationContract   imports NavigationCore only
#   RefPicker               imports NavigationCore, NavigatorDependency, and the contracts of the entities it can pick
#   feature                 imports NavigationCore, NavigatorDependency, RefPicker, and any module's contract
#                           (to navigate there) — never another feature
set -euo pipefail
cd "$(dirname "$0")/../MyLibrary/Sources"

status=0
imports_of() { grep -rhoE '^import [A-Za-z]+' "$1" | awk '{print $2}' | sort -u; }
local_modules=$(ls -d */ | tr -d / | tr "\n" " ")

check() { # module, allowed local imports...
  local module=$1; shift
  for imported in $(imports_of "$module"); do
    [[ " $local_modules " == *" $imported "* ]] || continue        # third-party / system
    [[ " $* " == *" $imported "* ]] && continue
    echo "✘ $module imports $imported"; status=1
  done
}

check NavigationCore
check NavigatorDependency NavigationCore
check RefPicker NavigationCore NavigatorDependency IssuesNavigationContract
for contract in *NavigationContract; do check "$contract" NavigationCore; done
contracts="IssuesNavigationContract ScreenBNavigationContract ScreenCNavigationContract ScreenDNavigationContract"
check IssuesDomain   NavigationCore NavigatorDependency RefPicker $contracts
check ScreenBFeature NavigationCore NavigatorDependency $contracts
check ScreenCKit     NavigationCore $contracts
check ScreenDKit     NavigationCore $contracts

[ $status -eq 0 ] && echo "✔ Module boundaries clean"
exit $status
