set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(CMAKE_C_COMPILER "${TELINK_TOOLCHAIN_PATH}gcc")
set(CMAKE_ASM_COMPILER "${TELINK_TOOLCHAIN_PATH}gcc")
set(CMAKE_LINKER "${TELINK_TOOLCHAIN_PATH}ld")
set(CMAKE_AR "${TELINK_TOOLCHAIN_PATH}ar")
set(CMAKE_OBJCOPY "${TELINK_TOOLCHAIN_PATH}objcopy")
set(CMAKE_OBJDUMP "${TELINK_TOOLCHAIN_PATH}objdump")
set(CMAKE_SIZE "${TELINK_TOOLCHAIN_PATH}size")

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_C_STANDARD_LIBRARIES "")

set(CMAKE_C_LINK_EXECUTABLE
    "<CMAKE_LINKER> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>"
)

add_compile_options(
    -Wall
    -O2
    -ffunction-sections
    -fdata-sections
    -fpack-struct
    -fshort-enums
    -finline-small-functions
    -fshort-wchar
    -fms-extensions
)
