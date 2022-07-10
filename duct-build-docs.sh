#!/usr/bin/env bash
# vim: set ft=sh syn=bash :
#
# Copyright (C) 2022 Chris 'sh0shin' Frage
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License, version 3,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#

set -eu

# shellcheck disable=SC1090,SC2155

# plugin skip list
PLUG_SKIP=(
  duct-debug
)

# variable warn list
DOCS_WARN=(
  GITHUB_TOKEN
  GITLAB_TOKEN
)

# git root
GIT_ROOT_DIR="$( git rev-parse --show-toplevel )"

# docs/plugins
DOCS_ROOT_DIR="${GIT_ROOT_DIR}/docs"
DOCS_PLUG_DIR="${DOCS_ROOT_DIR}/plug"

DOCS_PLUG_TYPE="${1:-}"

if [[ -z "$DOCS_PLUG_TYPE" ]]
then
  if [[ "${GIT_ROOT_DIR##*/}" == "duct-core" ]]
  then
    DOCS_PLUG_TYPE="core"
  fi
fi

if [[ ! -d "$DOCS_ROOT_DIR" ]]
then
  mkdir -p "$DOCS_ROOT_DIR"
fi

if [[ ! -d "$DOCS_PLUG_DIR" ]]
then
  mkdir -p "$DOCS_PLUG_DIR"
fi

# code tests
DOCS_CODE_DIR="${GIT_ROOT_DIR}/test"

if [[ ! -d "$DOCS_CODE_DIR" ]]
then
  mkdir -p "$DOCS_CODE_DIR"
fi

DOCS_PLUG="${DOCS_ROOT_DIR}/PLUG.md"
DOCS_LIST=(
  "[//]: # ( vim: set ft=markdown : )"
  ""
  "# Plugins"
  ""
  "| Name | Description |"
  "|:-----|:------------|"
)
printf "%s\n" "${DOCS_LIST[@]}" > "$DOCS_PLUG"

# warn and unset variables
for WARN in "${DOCS_WARN[@]}"
do
  if declare -p "$WARN" >/dev/null 2>&1
  then
    echo "WARNING: $WARN is set!"
    unset "$WARN"
  fi
done

__proc_vars() {
  local VARS_PLUG="$1"
  shift
  local -a VARS_LIST=( "$@" )

  local -a VARS_CODE=()
  local VARS
  local VARS_CONT
  local VARS_DESC
  local VARS_NAME
  local VARS_TYPE
  local VARS_VALS
  local VARS_XTRA

  for VARS in "${VARS_LIST[@]}"
  do
    shopt -s extglob

    VARS_TYPE="${VARS%:*}"
    VARS_CONT="${VARS#*:}"
    VARS_NAME="${VARS_CONT%%=*}"
    VARS_VALS="${VARS_CONT#*=}"
    VARS_DESC="$( grep -B 1 -E "^(declare|readonly)(.*)? ${VARS_NAME}" "$VARS_PLUG" | head -n 1 )"

    # description
    if [[ "$VARS_DESC" =~ ^#\ (.*) ]]
    then
      VARS_DESC="${BASH_REMATCH[1]}"
    else
      VARS_DESC="FIXME"
    fi

    # read-only
    if [[ "$VARS_TYPE" =~ r$ ]]
    then
      VARS_XTRA=" (READ-ONLY)"
    else
      VARS_XTRA=""
    fi

    # pretty array
    if [[ "$VARS_TYPE" =~ a ]]
    then
      for VALS in $VARS_VALS
      do
        _VARS_VALS+="${VALS//\[+([[:digit:]])\]=/} "
      done

      VARS_VALS="$_VARS_VALS"
      unset _VARS_VALS
    fi

    if [[ "$VARS_TYPE" =~ A ]]
    then
      : # TODO
    fi

    # reset expanded
    if [[ "$VARS_VALS" =~ ${TMPDIR:-"/tmp"} ]]
    then
      VARS_VALS="${VARS_VALS//$TMPDIR/\${TMPDIR:-"/tmp"\}}"
    fi

    if [[ "$VARS_VALS" =~ $PWD ]]
    then
      VARS_VALS="${VARS_VALS//$PWD/\$PWD}"
    fi

    if [[ "$VARS_VALS" =~ $HOME ]]
    then
      VARS_VALS="${VARS_VALS//$HOME/\${HOME\}}"
    fi

    VARS_VALS="${VARS_VALS##*([[:space:]])}"
    VARS_VALS="${VARS_VALS%%*([[:space:]])}"

    VARS_CODE+=(
      "# ${VARS_DESC}${VARS_XTRA}"
      "${VARS_NAME}=${VARS_VALS}"
      ""
    )
  done
  unset 'VARS_CODE[-1]'
  shopt -u globstar
  printf "%s\n" "${VARS_CODE[@]}"
}

if [[ "$DOCS_PLUG_TYPE" == "core" ]]
then
  DOCS_PLUG_SUB="/plug/core/"
else
  DOCS_PLUG_SUB="/plug/"
fi

echo "${GIT_ROOT_DIR}${DOCS_PLUG_SUB}duct-*"
for PLUG in "${GIT_ROOT_DIR}${DOCS_PLUG_SUB}"duct-*
do
  PLUG_FILE="${PLUG##*/}"
  PLUG_NAME="${PLUG_FILE}"  # modify name?!
  PLUG_DOWN="${DOCS_PLUG_DIR}/${PLUG_FILE}.md"
  PLUG_PROC=true
  PLUG_VERS=""

  # skip plugins
  for SKIP in "${PLUG_SKIP[@]}"
  do
    if [[ "$PLUG_FILE" =~ ^${SKIP}$ ]]
    then
      echo "SKIPPING: $PLUG_FILE"
      PLUG_PROC=false
    fi
  done

  if [[ "$PLUG_PROC" != true ]]
  then
    continue
  fi

  if [[ -f "$PLUG" ]] && [[ -s "$PLUG" ]] #&& [[ "${PLUG##*/}" == "duct-utils" ]]
  then
    (
      # duct main vars
      DUCT_ROOT_DIR="$GIT_ROOT_DIR"
      DUCT_PLUG_DIR="${DUCT_ROOT_DIR}/plugins"

      # shellcheck disable=SC1090
      source "${PLUG:?}"

      declare PLUG_DESC=""
      declare -a DOCS_LIST=()
      declare -a PLUG_DOCS=()
      declare -a FUNC_DOCS=()

      # description
      PLUG_DESC="$( grep -A 1 -E "^# $PLUG_FILE" "$PLUG" | tail -n 1 )"
      if [[ "$PLUG_DESC" =~ ^#\ (.*)$ ]]
      then
        PLUG_DESC="${BASH_REMATCH[1]}"
      else
        PLUG_DESC="FIXME"
      fi

      # append plugin to plugin list
      DOCS_LIST=(
        "| [$PLUG_FILE](${DOCS_PLUG_DIR##*/}/${PLUG_FILE}.md) | $PLUG_DESC |"
      )
      printf "%s\n" "${DOCS_LIST[@]}" >> "$DOCS_PLUG"

      # plugin functions
      readarray -t PLUG_ALL_FUNC < <( declare -F | grep -E "__duct_" )

      # plugin variables
      readarray -t PLUG_ALL_VARS < <( declare -p | grep -E "DUCT_" )

      FUNC_DOCS=()
      PLUG_VARS=()
      for FUNC in "${PLUG_ALL_FUNC[@]}"
      do
        if [[ "$FUNC" =~ ^declare\ (.*)\ (.*)$ ]]
        then
          FUNC_VARS=()
          FUNC_TYPE="${BASH_REMATCH[1]}"
          FUNC_NAME="${BASH_REMATCH[2]}"

          FUNC_BASE="${FUNC_NAME//__duct_}"
          FUNC_CALL="duct ${FUNC_BASE//_/ }"

          readarray -t FUNC_INFO < <( grep -B5 -E "^${FUNC_NAME}" "$PLUG" || : )

          #echo "$FUNC_CALL"
          #printf "%s\n" "${FUNC_INFO[@]}"

          FUNC_DEPS=""
          FUNC_INTL="FIXME"
          FUNC_LIFE="none"
          FUNC_DESC="FIXME"
          FUNC_OPTS=""

          for INFO in "${FUNC_INFO[@]}"
          do
            if [[ "$INFO" =~ (dependencies|deps):\ (.*) ]]
            then
              FUNC_DEPS="${BASH_REMATCH[2]}"
            elif [[ "$INFO" =~ (internal|intl):\ (.*) ]]
            then
              FUNC_INTL="${BASH_REMATCH[2]}"
            elif [[ "$INFO" =~ (lifecycle|life):\ (.*) ]]
            then
              FUNC_LIFE="${BASH_REMATCH[2]}"
            elif [[ "$INFO" =~ (description|desc):\ (.*) ]]
            then
              FUNC_DESC="${BASH_REMATCH[2]}"
            elif [[ "$INFO" =~ (options|opts):\ (.*) ]]
            then
              FUNC_OPTS=" ${BASH_REMATCH[2]}"
            fi
          done

          if [[ "$FUNC_LIFE" =~ ^(core|main|stable) ]]
          then
            FUNC_LIFE=""
          else
            FUNC_LIFE=" ($FUNC_LIFE)"
          fi

          FUNC_DOCS+=(
            "## ${FUNC_CALL^^}${FUNC_LIFE^^}"
            ""
            "$FUNC_DESC"
            ""
          )

          # sort in vars (func)
          for VARS in "${PLUG_ALL_VARS[@]}"
          do
            if [[ "$VARS" =~ declare\ ([Aa-z\-]+)\ (.*) ]]
            then
              VARS_TYPE="${BASH_REMATCH[1]}"
              VARS_CONT="${BASH_REMATCH[2]}"

              # skip hidden & core variable
              if [[ "$VARS_CONT" =~ ^(_DUCT_|DUCT_PLUG_DIR|DUCT_ROOT_DIR) ]]
              then
                # remove hidden & core variable
                for IDX in "${!PLUG_ALL_VARS[@]}"
                do
                  if [[ "${PLUG_ALL_VARS[IDX]}" == "$VARS" ]]
                  then
                    unset 'PLUG_ALL_VARS[IDX]'
                  fi
                done

                PLUG_ALL_VARS=( "${PLUG_ALL_VARS[@]}" ) # rewrite index
                continue
              fi

              FUNC_TO_VARS="${FUNC_NAME^^}"
              FUNC_TO_VARS="${FUNC_TO_VARS//__}"

              if [[ "$VARS_CONT" =~ ^${FUNC_TO_VARS} ]]
              then
                # remove processed variable
                for IDX in "${!PLUG_ALL_VARS[@]}"
                do
                  if [[ "${PLUG_ALL_VARS[IDX]}" == "$VARS" ]]
                  then
                    unset 'PLUG_ALL_VARS[IDX]'
                  fi
                done

                PLUG_ALL_VARS=( "${PLUG_ALL_VARS[@]}" )     # rewrite index
                FUNC_VARS+=( "${VARS_TYPE}:${VARS_CONT}" )  # append function vars
              fi
            fi
          done # end of func vars

          # function variables
          if [[ "${#FUNC_VARS[@]}" -gt 0 ]]
          then
            FUNC_DOCS+=(
              "## Variables and defaults"
              ""
              '```sh'
            )

            # process vars
            FUNC_DOCS+=(
              "$( __proc_vars "$PLUG" "${FUNC_VARS[@]}" )"
            )

            FUNC_DOCS+=(
              '```'
              ""
            )
          fi

          # dependencies
          if [[ -n "$FUNC_DEPS" ]]
          then
            FUNC_DOCS+=(
              "## Dependencies"
              ""
            )
            for DEPS in $FUNC_DEPS
            do
              FUNC_DOCS+=(
                "- [$DEPS](${DEPS}.md)"
              )
            done
            FUNC_DOCS+=(
              ""
            )
          fi

          # usage
          if [[ "$FUNC_INTL" != true ]]
          then
            FUNC_DOCS+=(
              "## Usage"
              ""
              '```sh'
              "${FUNC_CALL}${FUNC_OPTS}"
              '```'
              ""
            )
            if [[ -s "${DOCS_CODE_DIR}/${PLUG_NAME}/${FUNC_NAME//__}.sh" ]]
            then
              FUNC_DOCS+=(
                "## Example"
                ""
                '```sh'
              )
              readarray -t EXAMPLE < "${DOCS_CODE_DIR}/${PLUG_NAME}/${FUNC_NAME//__}.sh"

              for _EXAMPLE in "${EXAMPLE[@]}"
              do
                if [[ $_EXAMPLE =~ ^DUCT_ROOT= ]]
                then
                  _EXAMPLE='DUCT_ROOT="/path/to/duct-bash"'
                fi
                FUNC_DOCS+=(
                  "$_EXAMPLE"
                )
              done

              FUNC_DOCS+=(
                '```'
                ""
              )
            else
              mkdir -p "${DOCS_CODE_DIR}/${PLUG_NAME}"
              touch "${DOCS_CODE_DIR}/${PLUG_NAME}/${FUNC_NAME//__}.sh"
              echo "MISSING: ${DOCS_CODE_DIR}/${PLUG_NAME}/${FUNC_NAME//__}.sh"
            fi

          else
            FUNC_DOCS+=(
              "_internal use only!_"
              ""
            )
          fi
        fi

        FUNC_DOCS+=(
          "---"
          ""
        )
      done # end of functions

      # plugin vars
      for VARS in "${PLUG_ALL_VARS[@]}"
      do
        if [[ "$VARS" =~ declare\ ([Aa-z\-]+)\ (.*) ]]
        then
          VARS_TYPE="${BASH_REMATCH[1]}"
          VARS_CONT="${BASH_REMATCH[2]}"

          #if [[ "$VARS_CONT" =~ ^DUCT_PLUG_(.*)_VERSION ]]
          #then
          #  PLUG_VERS="${VARS_CONT##*=}"
          #  PLUG_VERS="${PLUG_VERS//\"}"
          #  continue
          #fi

          PLUG_VARS+=( "${VARS_TYPE}:${VARS_CONT}" )
        fi
      done

      #if [[ -z "$PLUG_VERS" ]]
      #then
      #  echo "MISSING: $PLUG_NAME version information!"
      #fi

      PLUG_DOCS+=(
        "[//]: # ( vim: set ft=markdown : )"
        ""
        "# ${PLUG_NAME^^}"
        ""
        "$PLUG_DESC"
        ""
      )

      if [[ "${#PLUG_VARS[@]}" -gt 0 ]]
      then
        PLUG_DOCS+=(
          "## Plugin variables and defaults"
          ""
          '```sh'
        )

        # process vars
        PLUG_DOCS+=(
          "$( __proc_vars "$PLUG" "${PLUG_VARS[@]}" )"
        )

        PLUG_DOCS+=(
          '```'
          ""
        )
      fi

      # write plugin docs
      (
        # chomp
        while [[ "${FUNC_DOCS[-1]}" =~ (^\-\-\-$|^$) ]]
        do
          unset 'FUNC_DOCS[-1]'
        done

        printf "%s\n" "${PLUG_DOCS[@]}"
        printf "%s\n" "${FUNC_DOCS[@]}"
      ) > "$PLUG_DOWN"
    ) 2>&1
  fi
done
exit 0
