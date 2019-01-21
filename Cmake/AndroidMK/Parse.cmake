SET(MK_DEBUG OFF)
SET(MK_LINE_DEBUG OFF)
SET(MK_SHARED "SHARED")
SET(MK_STATIC "STATIC")
SET(MK_EXECAB "EXECAB")

SET(MOUDLE_START OFF)
#SET(IN_IF_BLOCK OFF)
#SET(IN_IF_BLOCK_NUM 0)

SET(TARGET_TEST true)
SET(TARGET_USES_HWC2 true)
SET(TARGET_BUILD_VARIANT eng)
SET(TARGET_BOARD_TEST TARGET_BOARD_PLATFORM)
SET(TARGET_BOARD_PLATFORM rk3399)
SET(TARGET_BOARD_PLATFORM_PRODUCT box)

include(${CMAKE_CURRENT_LIST_DIR}/ParseIf.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/addTarget.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/ParseValues.cmake)

function(parseLine line module_name type out_stop)

    if("${line}" MATCHES ".*CLEAR_VARS.*")
        initEnv()
        SET(MOUDLE_START ON PARENT_SCOPE)
        return()
    elseif("${line}" MATCHES ".*BUILD_SHARED_LIBRARY.*")
        if(MOUDLE_START AND "${module_name}" STREQUAL "${LOCAL_MODULE}" AND "${type}" STREQUAL "${MK_SHARED}")
            addTarget("${MK_SHARED}")
            set(${out_stop} ON PARENT_SCOPE)
        endif()
        SET(MOUDLE_START OFF PARENT_SCOPE)
        return()
    elseif("${line}" MATCHES ".*BUILD_STATIC_LIBRARY.*")
        if(MOUDLE_START AND "${module_name}" STREQUAL "${LOCAL_MODULE}" AND "${type}" STREQUAL "${MK_STATIC}")
            addTarget("${MK_STATIC}")
            set(${out_stop} ON PARENT_SCOPE)
        endif()
        SET(MOUDLE_START OFF PARENT_SCOPE)
        return()
    elseif("${line}" MATCHES ".*BUILD_EXECUTABLE.*")
        if(MOUDLE_START AND "${module_name}" STREQUAL "${LOCAL_MODULE}" AND "${type}" STREQUAL "${MK_EXECAB}")
            addTarget("${MK_EXECAB}")
            set(${out_stop} ON PARENT_SCOPE)
        endif()
        SET(MOUDLE_START OFF PARENT_SCOPE)
        return()
    elseif( "${line}" MATCHES "^( *)ifeq.*" )
        if(IN_IF_BLOCK)
            math(EXPR parseLine_block_num "${IN_IF_BLOCK_NUM} + 1")
            SET(IN_IF_BLOCK_NUM ${parseLine_block_num} PARENT_SCOPE)
        else()
            string(REPLACE "ifeq" "" line "${line}")
            string(STRIP "${line}" line)
            doIfeq("${line}" if_block)
            if(if_block)
                SET(IN_IF_BLOCK_NUM "0" PARENT_SCOPE)
            endif()
            SET(IN_IF_BLOCK ${if_block} PARENT_SCOPE)
        endif()
        return()
     elseif( "${line}" MATCHES "^( *)ifneq.*" )
        if(IN_IF_BLOCK)
            math(EXPR parseLine_block_num "${IN_IF_BLOCK_NUM} + 1")
            SET(IN_IF_BLOCK_NUM ${parseLine_block_num} PARENT_SCOPE)
        else()
            string(REPLACE "ifneq" "" line "${line}")
            string(STRIP "${line}" line)
            doIfneq("${line}" if_block)
            if(if_block)
                SET(IN_IF_BLOCK_NUM "0" PARENT_SCOPE)
            endif()
            SET(IN_IF_BLOCK ${if_block} PARENT_SCOPE)
        endif()
        return()
     elseif( "${line}" MATCHES "^( *)else.*" )
        if(NOT IN_IF_BLOCK_NUM)
            if(IN_IF_BLOCK)
                SET(IN_IF_BLOCK OFF PARENT_SCOPE)
            else()
                SET(IN_IF_BLOCK ON PARENT_SCOPE)
            endif()
        endif()
        return()
    elseif("${line}" MATCHES "^( *)endif.*")
        if(NOT IN_IF_BLOCK_NUM)
            if(MK_DEBUG)
                message("parseLine: ======= endif =======")
            endif()
            SET(IN_IF_BLOCK OFF PARENT_SCOPE)
        else()
            math(EXPR parseLine_block_num "${IN_IF_BLOCK_NUM} - 1")
            SET(IN_IF_BLOCK_NUM ${parseLine_block_num} PARENT_SCOPE)
            if(MK_DEBUG)
                message("parseLine:out of block num=${IN_IF_BLOCK_NUM}")
            endif()
        endif()
        return()
    elseif("${line}" MATCHES "^( *)include.*")
        if(MK_DEBUG)
            message("parseLine: current not supprot include")
        endif()
        return()
    endif()

    if(MK_DEBUG)
        message("parseLine:IN_IF_BLOCK     = ${IN_IF_BLOCK}")
        message("parseLine:IN_IF_BLOCK_NUM = ${IN_IF_BLOCK_NUM}")
    endif()

    if(IN_IF_BLOCK)
        if(MK_DEBUG)
            message("parseLine: ======= if block =======")
        endif()
        return()
    endif()

    parseValues("${line}" local_key)
    SET(${local_key} "${${local_key}}" PARENT_SCOPE)
endfunction()

function(initEnv)
    SET(LOCAL_PATH "" PARENT_SCOPE)
    SET(LOCAL_MODULE "" PARENT_SCOPE)
    SET(LOCAL_CFLAGS "" PARENT_SCOPE)
    SET(LOCAL_CPPFLAGS "" PARENT_SCOPE)
    SET(LOCAL_SRC_FILES "" PARENT_SCOPE)
    SET(LOCAL_C_INCLUDES "" PARENT_SCOPE)
    SET(LOCAL_SHARED_LIBRARIES "" PARENT_SCOPE)
    SET(LOCAL_STATIC_LIBRARIES "" PARENT_SCOPE)
endfunction()

function(parseAndroidMK module_name type)

    containsMoudle("${module_name}_${type}" is_find)
    if(is_find)
        return()
    endif()

    getMoudlePath("${type}" "${module_name}" path)
    if(NOT path)
        message("parseAndroidMK: ${type} ${module_name} not found!")
        return()
    endif()
    SET(local_path ${PROJECT_DIR}/${path})
    SET(mk_path ${local_path}/Android.mk)

    initEnv()
    message("AndroidMK:${mk_path}")
    SET(LOCAL_PATH ${local_path})
    if(MK_DEBUG)
        message("LOCAL_PATH:${LOCAL_PATH}")
    endif()
    File(STRINGS ${mk_path} MyFile)

    set(parseAndroidMK_stop OFF)

    foreach(line ${MyFile})
        # 读取文件的时候 \\n 会被转换成 " ;"需要替换掉
        string(STRIP "${line}" line)
        string(REPLACE " ;" "" line "${line}")
        string(REGEX REPLACE "(\t)+" " " line "${line}")
        string(REGEX REPLACE " +" " " line "${line}")
        if( "${line}" MATCHES "^( *)#.*")
            continue()
        endif()
        if( "${line}" MATCHES "^( *)LOCAL_PATH.*:=.*")
            continue()
        endif()
        string(REGEX REPLACE " +" " " line "${line}")
        if(MK_LINE_DEBUG)
            message("parseAndroidMK: ${line}")
        endif()
        parseLine("${line}" "${module_name}" "${type}" parseAndroidMK_stop)
        if(parseAndroidMK_stop)
            break()
        endif()
    endforeach()

    doMoudleDependencies("${module_name}_${type}")
endfunction()