#!/bin/sh

set -eu

SCRIPT_NAME=$(basename "$0")
TAB=$(printf '\t')

DEFAULT_ROOT="."
ONLY_INSTALLED=0
JSON_OUTPUT=0

HOME_DIR=${HOME:-}
UV_ROOT="${HOME_DIR}/.local/share/uv"
UV_PYTHON_ROOT="${UV_ROOT}/python"
UV_TOOLS_ROOT="${UV_ROOT}/tools"

usage() {
    cat <<EOF
${SCRIPT_NAME}

Inventory LiteLLM versions across local Python installs under a root directory and
common system locations.

This is a temporary quick first-pass helper for the LiteLLM package incident
discussed at https://news.ycombinator.com/item?id=47501729.
It does not execute discovered Python interpreters while inspecting environments.

Usage:
  ${SCRIPT_NAME} [--only-installed] [--json] [root]

Options:
  --only-installed  Only print locations where litellm is present.
  --json            Emit JSON instead of a tab-separated table.
  -h, --help        Show this help message and exit.
EOF
}

json_escape() {
    printf '%s' "$1" | awk '
        BEGIN { ORS = "" }
        {
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            gsub(/\t/, "\\t")
            gsub(/\r/, "\\r")
            gsub(/\n/, "\\n")
            print
        }
    '
}

normalize_path() {
    target=$1
    if [ -d "$target" ]; then
        (
            cd "$target" 2>/dev/null && pwd -P
        ) || printf '%s\n' "$target"
        return
    fi

    parent=$(dirname "$target")
    base=$(basename "$target")
    if [ -d "$parent" ]; then
        parent_abs=$(
            cd "$parent" 2>/dev/null && pwd -P
        ) || parent_abs=$parent
        printf '%s/%s\n' "$parent_abs" "$base"
        return
    fi

    printf '%s\n' "$target"
}

classify_kind() {
    root=$1
    default_kind=$2

    case "$root" in
        "$UV_PYTHON_ROOT"/*) printf 'uv-python\n'; return ;;
        "$UV_TOOLS_ROOT"/*) printf 'uv-tool\n'; return ;;
    esac

    if [ -d "$root/conda-meta" ]; then
        printf 'conda\n'
        return
    fi

    case "$root" in
        *conda*|*micromamba*)
            printf 'conda\n'
            return
            ;;
    esac

    if [ -f "$root/pyvenv.cfg" ]; then
        printf 'venv\n'
        return
    fi

    printf '%s\n' "$default_kind"
}

derive_prefix_from_site_packages() {
    site_dir=$(normalize_path "$1")
    parent=$(dirname "$site_dir")
    parent_name=$(basename "$parent")

    if [ "$parent_name" = "Lib" ]; then
        dirname "$parent"
        return
    fi

    case "$parent_name" in
        python*)
            lib_parent=$(dirname "$parent")
            lib_name=$(basename "$lib_parent")
            if [ "$lib_name" = "lib" ] || [ "$lib_name" = "lib64" ]; then
                dirname "$lib_parent"
                return
            fi
            if [ "$lib_name" = "lib" ] && [ "$(basename "$(dirname "$lib_parent")")" = "local" ]; then
                dirname "$(dirname "$lib_parent")"
                return
            fi
            ;;
    esac

    printf '%s\n' "$site_dir"
}

derive_prefix_from_interpreter() {
    interpreter=$(normalize_path "$1")
    parent=$(dirname "$interpreter")
    case "$(basename "$parent")" in
        bin|Scripts)
            dirname "$parent"
            return 0
            ;;
    esac
    return 1
}

add_candidate() {
    root=$1
    kind=$2
    source=$3
    interpreter=${4:-}
    root=$(normalize_path "$root")
    if [ -n "$interpreter" ]; then
        interpreter=$(normalize_path "$interpreter")
    fi
    printf '%s\t%s\t%s\t%s\n' "$root" "$kind" "$source" "$interpreter" >> "$RAW_CANDIDATES"
}

collect_scan_candidates() {
    find "$SCAN_ROOT" \
        \( \
            -name .cache -o -name .cargo -o -name .claude -o -name .codex -o \
            -name .cursor-server -o -name .docker -o -name .git -o -name .gradle -o \
            -name .hg -o -name .mypy_cache -o -name .next -o -name .npm -o \
            -name .nvm -o -name .ollama -o -name .parcel-cache -o -name .pnpm-store -o \
            -name .pytest_cache -o -name .ruff_cache -o -name .rustup -o -name .svn -o \
            -name .turbo -o -name .vscode -o -name .vscode-server -o \
            -name .vscode-server-insiders -o -name __pycache__ -o -name build -o \
            -name dist -o -name node_modules -o -name target \
        \) -prune -o \
        \( -type f -name pyvenv.cfg -print \) -o \
        \( -type d -name conda-meta -print \) -o \
        \( -type d \( -name site-packages -o -name dist-packages \) -print \)
}

collect_known_candidates() {
    for parent_kind in \
        "$UV_PYTHON_ROOT${TAB}uv-python${TAB}uv-python" \
        "$UV_TOOLS_ROOT${TAB}uv-tool${TAB}uv-tool"
    do
        parent=$(printf '%s' "$parent_kind" | awk -F '\t' '{print $1}')
        kind=$(printf '%s' "$parent_kind" | awk -F '\t' '{print $2}')
        source=$(printf '%s' "$parent_kind" | awk -F '\t' '{print $3}')
        [ -d "$parent" ] || continue
        for child in "$parent"/*; do
            [ -d "$child" ] || continue
            add_candidate "$child" "$kind" "$source" ""
        done
    done
}

collect_system_path_candidates() {
    SEARCH_DIRS_FILE="$TMPDIR/search_dirs.tsv"
    : > "$SEARCH_DIRS_FILE"

    printf '%s\n' "/usr/bin" >> "$SEARCH_DIRS_FILE"
    printf '%s\n' "/usr/local/bin" >> "$SEARCH_DIRS_FILE"
    printf '%s\n' "/bin" >> "$SEARCH_DIRS_FILE"
    if [ -n "$HOME_DIR" ]; then
        printf '%s\n' "$HOME_DIR/.local/bin" >> "$SEARCH_DIRS_FILE"
    fi

    old_ifs=$IFS
    IFS=:
    set -- ${PATH:-}
    IFS=$old_ifs
    for part in "$@"; do
        [ -n "$part" ] && printf '%s\n' "$part" >> "$SEARCH_DIRS_FILE"
    done

    awk '!seen[$0]++' "$SEARCH_DIRS_FILE" | while IFS= read -r directory; do
        [ -d "$directory" ] || continue
        for interpreter in "$directory"/python*; do
            [ -f "$interpreter" ] || continue
            case "$(basename "$interpreter")" in
                python|python[0-9]|python[0-9].[0-9]|python[0-9].[0-9][0-9])
                    :
                    ;;
                *)
                    continue
                    ;;
            esac
            prefix=""
            if prefix=$(derive_prefix_from_interpreter "$interpreter" 2>/dev/null); then
                :
            elif command -v readlink >/dev/null 2>&1; then
                resolved=$(readlink -f "$interpreter" 2>/dev/null || true)
                if [ -n "$resolved" ]; then
                    prefix=$(derive_prefix_from_interpreter "$resolved" 2>/dev/null || true)
                fi
            fi
            [ -n "$prefix" ] || continue
            kind=$(classify_kind "$prefix" "system")
            add_candidate "$prefix" "$kind" "system-path" "$interpreter"
        done
    done
}

dedupe_candidates() {
    awk -F '\t' '
        BEGIN { OFS = FS }
        {
            key = $1
            if (!(key in seen)) {
                seen[key] = 1
                order[++count] = key
                root[key] = $1
                kind[key] = $2
                source[key] = $3
                interp[key] = $4
                next
            }
            if (interp[key] == "" && $4 != "") {
                interp[key] = $4
            }
        }
        END {
            for (i = 1; i <= count; i++) {
                key = order[i]
                print root[key], kind[key], source[key], interp[key]
            }
        }
    ' "$RAW_CANDIDATES" > "$CANDIDATES"
}

collect_site_packages() {
    root=$1
    root_name=$(basename "$root")
    if [ "$root_name" = "site-packages" ] || [ "$root_name" = "dist-packages" ]; then
        printf '%s\n' "$root"
        return
    fi

    for candidate in "$root/Lib/site-packages" "$root/Lib/dist-packages"; do
        [ -d "$candidate" ] && normalize_path "$candidate"
    done

    for lib_root in "$root/lib" "$root/lib64" "$root/local/lib"; do
        [ -d "$lib_root" ] || continue
        for version_dir in "$lib_root"/python*; do
            [ -d "$version_dir" ] || continue
            for site_dir in "$version_dir/site-packages" "$version_dir/dist-packages"; do
                [ -d "$site_dir" ] && normalize_path "$site_dir"
            done
        done
    done | awk '!seen[$0]++'
}

read_version_file() {
    metadata_path=$1
    [ -f "$metadata_path" ] || return 0
    grep -m 1 '^Version:[[:space:]]*' "$metadata_path" 2>/dev/null | sed 's/^Version:[[:space:]]*//'
}

read_version_from_init() {
    init_path=$1
    [ -f "$init_path" ] || return 0
    sed -n 's/^[[:space:]]*__version__[[:space:]]*=[[:space:]]*["'"'"'\'"'"''"'"']\([^"'"'"'\'"'"''"'"']*\)["'"'"'\'"'"''"'"'].*/\1/p' "$init_path" 2>/dev/null | head -n 1
}

inspect_location() {
    root=$1
    kind=$2
    source=$3
    interpreter=$4

    SITE_TMP="$TMPDIR/site_packages.tmp"
    VERSIONS_TMP="$TMPDIR/versions.tmp"
    : > "$SITE_TMP"
    : > "$VERSIONS_TMP"

    collect_site_packages "$root" > "$SITE_TMP"

    while IFS= read -r site_dir; do
        [ -n "$site_dir" ] || continue

        for meta_dir in "$site_dir"/litellm-*.dist-info; do
            [ -d "$meta_dir" ] || continue
            version=$(read_version_file "$meta_dir/METADATA")
            if [ -z "$version" ]; then
                version=$(basename "$meta_dir")
                version=${version#litellm-}
                version=${version%.dist-info}
            fi
            [ -n "$version" ] && printf '%s\n' "$version" >> "$VERSIONS_TMP"
        done

        for meta_dir in "$site_dir"/litellm-*.egg-info; do
            [ -d "$meta_dir" ] || continue
            version=$(read_version_file "$meta_dir/PKG-INFO")
            if [ -z "$version" ]; then
                version=$(basename "$meta_dir")
                version=${version#litellm-}
                version=${version%.egg-info}
            fi
            [ -n "$version" ] && printf '%s\n' "$version" >> "$VERSIONS_TMP"
        done

        version=$(read_version_from_init "$site_dir/litellm/__init__.py")
        [ -n "$version" ] && printf '%s\n' "$version" >> "$VERSIONS_TMP"
    done < "$SITE_TMP"

    versions=$(awk '!seen[$0]++' "$VERSIONS_TMP" | paste -sd ',' -)
    site_packages=$(paste -sd '|' "$SITE_TMP")

    if [ -n "$versions" ]; then
        status=installed
    else
        status=not-installed
        versions=-
    fi

    [ -n "$site_packages" ] || site_packages=-
    [ -n "$interpreter" ] || interpreter=-

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$status" "$versions" "$kind" "$root" "$interpreter" "$source" "$site_packages" >> "$RESULTS"
}

sort_results() {
    awk -F '\t' '
        {
            status_rank = ($1 == "installed" ? 0 : 1)
            print status_rank "\t" $0
        }
    ' "$RESULTS" | sort -t "$TAB" -k1,1n -k4,4 | cut -f2- > "$SORTED_RESULTS"
}

print_table() {
    print_summary_after=1
    printf 'status\tlitellm\tkind\troot\tinterpreter\tsource\n'
    while IFS="$TAB" read -r status versions kind root interpreter source site_packages; do
        if [ "$ONLY_INSTALLED" -eq 1 ] && [ "$status" != "installed" ]; then
            continue
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$status" "$versions" "$kind" "$root" "$interpreter" "$source"
    done < "$SORTED_RESULTS"

    printf '\n'
    printf 'environments_checked\t%s\n' "$(wc -l < "$SORTED_RESULTS" | tr -d ' ')"
    printf 'litellm_locations\n'
    while IFS="$TAB" read -r status versions kind root interpreter source site_packages; do
        [ "$status" = "installed" ] || continue
        printf '%s\t%s\n' "$root" "$versions"
    done < "$SORTED_RESULTS"
}

print_json() {
    total=$(wc -l < "$SORTED_RESULTS" | tr -d ' ')

    printf '{\n'
    printf '  "locations": [\n'

    first=1
    while IFS="$TAB" read -r status versions kind root interpreter source site_packages; do
        if [ "$ONLY_INSTALLED" -eq 1 ] && [ "$status" != "installed" ]; then
            continue
        fi

        if [ "$first" -eq 0 ]; then
            printf ',\n'
        fi
        first=0

        printf '    {\n'
        printf '      "status": "%s",\n' "$(json_escape "$status")"
        if [ "$versions" = "-" ]; then
            printf '      "versions": [],\n'
        else
            printf '      "versions": ['
            version_first=1
            old_ifs=$IFS
            IFS=,
            set -- $versions
            IFS=$old_ifs
            for version in "$@"; do
                [ "$version_first" -eq 1 ] || printf ', '
                version_first=0
                printf '"%s"' "$(json_escape "$version")"
            done
            printf '],\n'
        fi
        printf '      "kind": "%s",\n' "$(json_escape "$kind")"
        printf '      "root": "%s",\n' "$(json_escape "$root")"
        if [ "$interpreter" = "-" ]; then
            printf '      "interpreter": null,\n'
        else
            printf '      "interpreter": "%s",\n' "$(json_escape "$interpreter")"
        fi
        printf '      "source": "%s",\n' "$(json_escape "$source")"
        if [ "$site_packages" = "-" ]; then
            printf '      "site_packages": []\n'
        else
            printf '      "site_packages": ['
            site_first=1
            old_ifs=$IFS
            IFS='|'
            set -- $site_packages
            IFS=$old_ifs
            for site_dir in "$@"; do
                [ "$site_first" -eq 1 ] || printf ', '
                site_first=0
                printf '"%s"' "$(json_escape "$site_dir")"
            done
            printf ']\n'
        fi
        printf '    }'
    done < "$SORTED_RESULTS"

    printf '\n  ],\n'
    printf '  "summary": {\n'
    printf '    "environments_checked": %s,\n' "$total"
    printf '    "litellm_locations": [\n'

    first=1
    while IFS="$TAB" read -r status versions kind root interpreter source site_packages; do
        [ "$status" = "installed" ] || continue
        if [ "$first" -eq 0 ]; then
            printf ',\n'
        fi
        first=0

        printf '      {\n'
        printf '        "root": "%s",\n' "$(json_escape "$root")"
        printf '        "versions": ['
        version_first=1
        old_ifs=$IFS
        IFS=,
        set -- $versions
        IFS=$old_ifs
        for version in "$@"; do
            [ "$version_first" -eq 1 ] || printf ', '
            version_first=0
            printf '"%s"' "$(json_escape "$version")"
        done
        printf '],\n'
        printf '        "kind": "%s",\n' "$(json_escape "$kind")"
        if [ "$interpreter" = "-" ]; then
            printf '        "interpreter": null,\n'
        else
            printf '        "interpreter": "%s",\n' "$(json_escape "$interpreter")"
        fi
        printf '        "source": "%s"\n' "$(json_escape "$source")"
        printf '      }'
    done < "$SORTED_RESULTS"

    printf '\n    ]\n'
    printf '  }\n'
    printf '}\n'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --only-installed)
            ONLY_INSTALLED=1
            ;;
        --json)
            JSON_OUTPUT=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
        *)
            DEFAULT_ROOT=$1
            shift
            if [ "$#" -gt 0 ]; then
                printf 'Too many arguments\n' >&2
                usage >&2
                exit 1
            fi
            break
            ;;
    esac
    shift
done

SCAN_ROOT=$(normalize_path "$DEFAULT_ROOT")
TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/inventory_litellm.XXXXXX")
trap 'rm -rf "$TMPDIR"' EXIT HUP INT TERM

RAW_CANDIDATES="$TMPDIR/raw_candidates.tsv"
CANDIDATES="$TMPDIR/candidates.tsv"
RESULTS="$TMPDIR/results.tsv"
SORTED_RESULTS="$TMPDIR/sorted_results.tsv"

: > "$RAW_CANDIDATES"
: > "$RESULTS"

collect_scan_candidates | while IFS= read -r path; do
    [ -n "$path" ] || continue
    base=$(basename "$path")
    case "$base" in
        pyvenv.cfg)
            add_candidate "$(dirname "$path")" "venv" "scan" ""
            ;;
        conda-meta)
            add_candidate "$(dirname "$path")" "conda" "scan" ""
            ;;
        site-packages|dist-packages)
            prefix=$(derive_prefix_from_site_packages "$path")
            kind=$(classify_kind "$prefix" "prefix")
            add_candidate "$prefix" "$kind" "scan" ""
            ;;
    esac
done

collect_known_candidates
collect_system_path_candidates
dedupe_candidates

while IFS="$TAB" read -r root kind source interpreter; do
    [ -n "$root" ] || continue
    inspect_location "$root" "$kind" "$source" "$interpreter"
done < "$CANDIDATES"

sort_results

if [ "$JSON_OUTPUT" -eq 1 ]; then
    print_json
else
    print_table
fi
