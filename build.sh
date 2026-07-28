#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}"
SDK_DIR="${ROOT_DIR}/tl_zigbee_sdk"
FW_CHECK_TOOL="${SDK_DIR}/tools/tl_check_fw2.out"

: "${CMAKE_GENERATOR:=Unix Makefiles}"
: "${BUILD_JOBS:=$(nproc 2>/dev/null || echo 4)}"

select_project() {
    local requested="${1:-sampleSwitch}"

    case "${requested}" in
        sampleSwitch|sampleswitch|switch)
            APP_NAME="sampleSwitch"
            PROJECT_NAME="sampleSwitch_8258"
            EQUIP_TYPE="ZED"
            ROLE_DEFINE="END_DEVICE"
            PROJECT_DEFINE="__PROJECT_TL_SWITCH__"
            ZB_LIBRARY="libzb_ed.a"
            ;;
        sampleGW|samplegw|gw)
            APP_NAME="sampleGW"
            PROJECT_NAME="sampleGW_8258"
            EQUIP_TYPE="ZC"
            ROLE_DEFINE="COORDINATOR"
            PROJECT_DEFINE="__PROJECT_TL_GW__"
            ZB_LIBRARY="libzb_coordinator.a"
            ;;
        *)
            error "不支持的应用: ${requested}"
            echo "支持的应用: sampleSwitch, sampleGW"
            return 1
            ;;
    esac

    BUILD_DIR="${ROOT_DIR}/build/${PROJECT_NAME}"
}

resolve_toolchain_prefix() {
    local configured="${TC32_TOOLCHAIN_PATH:-${TELINK_TOOLCHAIN_PATH:-}}"
    local compiler

    if [[ -n "${configured}" ]]; then
        if [[ -d "${configured}" ]]; then
            echo "${configured%/}/tc32-elf-"
        else
            echo "${configured}"
        fi
        return
    fi

    compiler="$(command -v tc32-elf-gcc 2>/dev/null || true)"
    if [[ -n "${compiler}" ]]; then
        echo "${compiler%gcc}"
    elif [[ -x "/home/onium/tools/tc32/bin/tc32-elf-gcc" ]]; then
        echo "/home/onium/tools/tc32/bin/tc32-elf-"
    else
        echo "tc32-elf-"
    fi
}

TOOLCHAIN_PREFIX="$(resolve_toolchain_prefix)"

show_help() {
    cat <<EOF
用法: ./build.sh <action> [app]

Actions:
  all      重新配置并全量构建
  cmake    仅配置 CMake 构建目录
  make     增量构建；尚未配置时会先执行 cmake
  clean    清理指定应用的构建产物
  help     显示帮助

Apps:
  sampleSwitch
             8258 End Device，默认应用
  sampleGW   8258 Coordinator

环境变量:
  TC32_TOOLCHAIN_PATH / TELINK_TOOLCHAIN_PATH
             tc32-elf- 工具链目录或完整前缀；未设置时优先从 PATH 查找
  BUILD_JOBS 并行编译数，默认 nproc
  CMAKE_GENERATOR
             CMake 生成器，默认 Unix Makefiles

输出目录:
  build/sampleSwitch_8258/
  build/sampleGW_8258/

示例:
  ./build.sh all
  ./build.sh all sampleGW
  ./build.sh make sampleGW
  ./build.sh clean sampleGW

脚本构建官方 SDK 的 8258 sampleSwitch（ZED）或 sampleGW（Coordinator），
配置取自对应应用的 app_cfg.h；不会复制固件到其他仓库。
EOF
}

tool_exists() {
    local tool="$1"

    [[ -x "${TOOLCHAIN_PREFIX}${tool}" ]] ||
        command -v "${TOOLCHAIN_PREFIX}${tool}" >/dev/null 2>&1
}

check_prereqs() {
    local errors=0
    local tool

    for tool in cmake make sha256sum; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            error "缺少构建工具: ${tool}"
            errors=$((errors + 1))
        fi
    done

    for tool in gcc ld ar objcopy objdump size; do
        if ! tool_exists "${tool}"; then
            error "8258 工具链不可用: ${TOOLCHAIN_PREFIX}${tool}"
            errors=$((errors + 1))
        fi
    done

    for path in \
        "${SDK_DIR}/apps/${APP_NAME}/app_cfg.h" \
        "${SDK_DIR}/platform/boot/8258/boot_8258.link" \
        "${SDK_DIR}/platform/lib/libdrivers_8258.a" \
        "${SDK_DIR}/zigbee/lib/tc32/${ZB_LIBRARY}" \
        "${FW_CHECK_TOOL}"; do
        if [[ ! -f "${path}" ]]; then
            error "缺少构建输入: ${path}"
            errors=$((errors + 1))
        fi
    done

    if [[ ${errors} -gt 0 ]]; then
        error "前置检查失败，共 ${errors} 项。"
        return 1
    fi
}

run_cmake() {
    info "配置 ${PROJECT_NAME}: MCU=8258, role=${EQUIP_TYPE}"
    cmake -G "${CMAKE_GENERATOR}" \
        -S "${ROOT_DIR}" \
        -B "${BUILD_DIR}" \
        -DTELINK_APP="${APP_NAME}" \
        -DTC32_TOOLCHAIN_PATH="${TOOLCHAIN_PREFIX}" \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
}

run_build() {
    local clean_first="${1:-false}"
    local -a build_args=(--build "${BUILD_DIR}" --parallel "${BUILD_JOBS}")

    if [[ ! -f "${BUILD_DIR}/CMakeCache.txt" ]]; then
        run_cmake
    fi
    if [[ "${clean_first}" == "true" ]]; then
        build_args+=(--clean-first)
        info "全量编译 ${PROJECT_NAME} (jobs: ${BUILD_JOBS})..."
    else
        info "增量编译 ${PROJECT_NAME} (jobs: ${BUILD_JOBS})..."
    fi

    cmake "${build_args[@]}"
}

run_fw_check() {
    local bin_path="${BUILD_DIR}/${PROJECT_NAME}.bin"
    local checker="${FW_CHECK_TOOL}"
    local temp_dir=""

    if [[ ! -x "${checker}" ]]; then
        temp_dir="$(mktemp -d)"
        checker="${temp_dir}/tl_check_fw2.out"
        cp "${FW_CHECK_TOOL}" "${checker}"
        chmod +x "${checker}"
    fi

    "${checker}" "${bin_path}"

    if [[ -n "${temp_dir}" ]]; then
        rm -f "${checker}"
        rmdir "${temp_dir}"
    fi
}

verify_build() {
    local extension
    local path
    local elf_path="${BUILD_DIR}/${PROJECT_NAME}.elf"
    local bin_path="${BUILD_DIR}/${PROJECT_NAME}.bin"

    for extension in elf map; do
        path="${BUILD_DIR}/${PROJECT_NAME}.${extension}"
        if [[ ! -s "${path}" ]]; then
            error "构建产物不存在或为空: ${path}"
            return 1
        fi
    done

    if [[ ! -f "${BUILD_DIR}/compile_commands.json" ]]; then
        error "缺少 compile_commands.json: ${BUILD_DIR}"
        return 1
    fi
    if ! grep -q -- "-DMCU_CORE_8258=1" "${BUILD_DIR}/compile_commands.json"; then
        error "编译命令未包含 MCU_CORE_8258=1"
        return 1
    fi
    if ! grep -q -- "-D${ROLE_DEFINE}=1" "${BUILD_DIR}/compile_commands.json"; then
        error "编译命令未包含 ${ROLE_DEFINE}=1"
        return 1
    fi
    if ! grep -q -- "-D${PROJECT_DEFINE}=1" "${BUILD_DIR}/compile_commands.json"; then
        error "编译命令未包含 ${PROJECT_DEFINE}=1"
        return 1
    fi

    # tl_check_fw2.out 会原地追加校验字段；每次先从 ELF 重建 BIN，避免增量验证重复追加。
    "${TOOLCHAIN_PREFIX}objcopy" -v -O binary "${elf_path}" "${bin_path}"
    run_fw_check
    [[ -s "${bin_path}" ]] || { error "固件不存在或为空: ${bin_path}"; return 1; }
    info "ELF SHA256: $(sha256sum "${elf_path}" | awk '{print $1}')"
    info "BIN SHA256: $(sha256sum "${bin_path}" | awk '{print $1}')"
    success "固件: ${bin_path}"
}

clean_build() {
    if [[ -f "${BUILD_DIR}/CMakeCache.txt" ]]; then
        cmake --build "${BUILD_DIR}" --target clean
    fi
    cmake -E rm -f \
        "${BUILD_DIR}/${PROJECT_NAME}.bin" \
        "${BUILD_DIR}/${PROJECT_NAME}.map"
    success "已清理: ${BUILD_DIR}"
}

main() {
    local action="${1:-help}"
    local app="${2:-sampleSwitch}"

    case "${action}" in
        help|-h|--help)
            show_help
            ;;
        all)
            select_project "${app}"
            check_prereqs
            run_cmake
            run_build true
            verify_build
            ;;
        cmake)
            select_project "${app}"
            check_prereqs
            run_cmake
            ;;
        make)
            select_project "${app}"
            check_prereqs
            run_build false
            verify_build
            ;;
        clean)
            select_project "${app}"
            clean_build
            ;;
        *)
            error "未知操作: ${action}"
            show_help
            return 1
            ;;
    esac
}

main "$@"
