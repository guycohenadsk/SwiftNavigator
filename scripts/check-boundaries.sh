#!/usr/bin/env bash
# Audits the module rules. Package.swift already makes forbidden imports a compile error; this
# catches someone loosening Package.swift to "fix" one. Exits non-zero on any violation.
#
#   NavigationCore          imports nothing from this package
#   <X>NavigationContract   imports NavigationCore only
#   RefPicker               imports NavigationCore, NavigatorDependency (shared component)
#   feature                 imports NavigationCore, NavigatorDependency, RefPicker, and its OWN contract only
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
check RefPicker NavigationCore NavigatorDependency
for contract in *NavigationContract; do check "$contract" NavigationCore; done
check IssuesDomain   NavigationCore NavigatorDependency IssuesNavigationContract RefPicker
check ScreenBFeature NavigationCore NavigatorDependency ScreenBNavigationContract
check ScreenCKit     NavigationCore ScreenCNavigationContract
check ScreenDKit     NavigationCore ScreenDNavigationContract

[ $status -eq 0 ] && echo "✔ Module boundaries clean"
exit $status
