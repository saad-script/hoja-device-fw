#!/usr/bin/env bash
#
# Build every ProGCC model across all platform roots.
#
# ProGCC projects are spread over several platform directories, each of which is
# its own CMake root with its own board/SDK settings:
#   rp2040/     -> progcc_3, progcc_3p, progcc_3.1, progcc_3.2
#   rp2040_w/   -> progcc_3.3, progcc_4.0
#   rp2350a_w/  -> progcc_3s
# Projects are discovered automatically, so new models/platforms just work.
#
# Usage:
#   ./build_progcc.sh                     # clean, configure, build every progcc model
#   ./build_progcc.sh progcc_3.2 progcc_3s   # build only the given models
#   ./build_progcc.sh --platform rp2040   # build only models on a platform
#   ./build_progcc.sh --no-clean          # incremental (skip build dir wipe)
#   ./build_progcc.sh --list              # list discovered models and exit
#   ./build_progcc.sh -j 8                # parallel job count (default: nproc)
#
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDS_OUT="${ROOT_DIR}/builds"

CLEAN=1
LIST_ONLY=0
PLATFORM_FILTER=""
JOBS="$( (nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) )"
REQUESTED=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-clean)        CLEAN=0; shift ;;
        --clean)           CLEAN=1; shift ;;
        --list|-l)         LIST_ONLY=1; shift ;;
        --platform|-p)     PLATFORM_FILTER="$2"; shift 2 ;;
        -j)                JOBS="$2"; shift 2 ;;
        -j*)               JOBS="${1#-j}"; shift ;;
        -h|--help)         sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)                echo "Unknown option: $1" >&2; exit 2 ;;
        *)                 REQUESTED+=("$1"); shift ;;
    esac
done

# ---------------------------------------------------------------------------
# Discover "<platform>/<target>" pairs for every progcc_* project.
# A project only has a CMake target if it is listed in that platform's
# BULK_PROJECTS_DIRS, so that is the source of truth. Anything on disk but
# not registered there is reported as skipped.
# ---------------------------------------------------------------------------
PAIRS=()
SKIPPED=()

bulk_projects() { # $1 = platform CMakeLists.txt
    awk '/set\(BULK_PROJECTS_DIRS/{inblock=1; next} inblock && /^[[:space:]]*\)/{inblock=0} inblock{gsub(/[[:space:]]/,""); if ($0 != "") print}' "$1"
}

while IFS= read -r main_c; do
    proj_dir="$(dirname "${main_c}")"
    target="$(basename "${proj_dir}")"
    platform="$(basename "$(dirname "${proj_dir}")")"
    platform_cmake="${ROOT_DIR}/${platform}/CMakeLists.txt"
    [[ -f "${platform_cmake}" ]] || continue
    [[ -n "${PLATFORM_FILTER}" && "${platform}" != "${PLATFORM_FILTER}" ]] && continue
    if [[ ${#REQUESTED[@]} -gt 0 ]]; then
        found=0
        for want in "${REQUESTED[@]}"; do
            [[ "${want}" == "${target}" ]] && found=1
        done
        [[ ${found} -eq 1 ]] || continue
    fi

    # Only build it if the platform CMakeLists actually registers it
    if bulk_projects "${platform_cmake}" | grep -qx "${target}"; then
        PAIRS+=("${platform}/${target}")
    else
        SKIPPED+=("${platform}/${target}")
    fi
done < <(find "${ROOT_DIR}" -mindepth 3 -maxdepth 3 -path '*/progcc_*/main.c' | sort)

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo "==> Skipping (not listed in their platform's BULK_PROJECTS_DIRS):"
    printf '      %s\n' "${SKIPPED[@]}"
fi

# Fail loudly on explicitly requested models that produced no target
for want in "${REQUESTED[@]-}"; do
    [[ -z "${want}" ]] && continue
    if [[ " ${PAIRS[*]} " != *"/${want} "* ]]; then
        if [[ " ${SKIPPED[*]-} " == *"/${want} "* ]]; then
            echo "!! Model '${want}' exists on disk but is not registered in its platform's BULK_PROJECTS_DIRS" >&2
        else
            echo "!! Requested model '${want}' not found" >&2
        fi
        exit 1
    fi
done

if [[ ${#PAIRS[@]} -eq 0 ]]; then
    echo "No buildable progcc projects found under ${ROOT_DIR}" >&2
    exit 1
fi

# Unique, ordered list of platforms involved
PLATFORMS=()
for pair in "${PAIRS[@]}"; do
    p="${pair%%/*}"
    [[ " ${PLATFORMS[*]-} " == *" ${p} "* ]] || PLATFORMS+=("${p}")
done

if [[ ${LIST_ONLY} -eq 1 ]]; then
    printf '%s\n' "${PAIRS[@]}"
    exit 0
fi

echo "==> Platforms: ${PLATFORMS[*]}"
echo "==> Models:    ${PAIRS[*]}"

FAILED=()
BUILT=()

for platform in "${PLATFORMS[@]}"; do
    platform_dir="${ROOT_DIR}/${platform}"
    build_dir="${platform_dir}/build"

    echo
    echo "##############################################"
    echo "## Platform: ${platform}"
    echo "##############################################"

    if [[ ${CLEAN} -eq 1 ]]; then
        echo "==> Cleaning build dirs in ${platform}/ and library/artifacts/${platform}"
        find "${platform_dir}" -type d -name build -prune -exec rm -rf {} +
        rm -rf "${ROOT_DIR}/library/artifacts/${platform}"
    fi

    echo "==> Configuring ${build_dir}"
    if ! cmake -S "${platform_dir}" -B "${build_dir}" -DCMAKE_EXPORT_COMPILE_COMMANDS=ON; then
        echo "!! CMake configure failed for ${platform}" >&2
        for pair in "${PAIRS[@]}"; do
            [[ "${pair%%/*}" == "${platform}" ]] && FAILED+=("${pair}")
        done
        continue
    fi

    for pair in "${PAIRS[@]}"; do
        [[ "${pair%%/*}" == "${platform}" ]] || continue
        target="${pair##*/}"

        echo
        echo "=============================================="
        echo "==> Building ${platform}/${target}"
        echo "=============================================="
        if cmake --build "${build_dir}" --target "${target}" -j "${JOBS}"; then
            echo "==> ${target}: OK"
            BUILT+=("${pair}")
        else
            echo "!! ${target}: FAILED" >&2
            FAILED+=("${pair}")
        fi
    done
done

echo
echo "=============================================="
echo "Summary"
echo "=============================================="
for pair in "${PAIRS[@]}"; do
    target="${pair##*/}"
    uf2="${BUILDS_OUT}/${target}/${target}.uf2"
    if [[ " ${FAILED[*]-} " == *" ${pair} "* ]]; then
        printf '  FAIL  %-28s\n' "${pair}"
    elif [[ -f "${uf2}" ]]; then
        printf '  OK    %-28s -> %s\n' "${pair}" "${uf2}"
    else
        printf '  OK    %-28s (no uf2 at %s)\n' "${pair}" "${uf2}"
    fi
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo
    echo "${#FAILED[@]} of ${#PAIRS[@]} model(s) failed."
    exit 1
fi
echo
echo "All ${#PAIRS[@]} ProGCC models built successfully."
