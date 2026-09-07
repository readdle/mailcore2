set(CMAKE_INCLUDE_CURRENT_DIR ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include(public-headers)
include(core)
include(async)
include(objc)
include(LibFindMacros)

IF(APPLE)
  execute_process(COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/../scripts/get-mac.sh"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../scripts")
ENDIF()

file(GLOB_RECURSE
  source_files
  *.h
  *.m
  *.c
)

SET_SOURCE_FILES_PROPERTIES(
  ${source_files}
  PROPERTIES LANGUAGE C
)

set(MAILCORE2_PUBLIC_HEADERS_DIR "${CMAKE_CURRENT_BINARY_DIR}/include")

file(COPY
  ${public_headers}

  DESTINATION
  "${MAILCORE2_PUBLIC_HEADERS_DIR}/MailCore"
)

include_directories(
  ${additional_includes}
  ${GLIB2_INCLUDE_DIRS}
)

if(WIN32)
  set(MAILCORE2_LIB_TARGET mailcore2)
else()
  set(MAILCORE2_LIB_TARGET MailCore)
endif()

add_library(${MAILCORE2_LIB_TARGET}
  ${core_files}
  ${async_files}
  ${objc_files}
)

target_include_directories(${MAILCORE2_LIB_TARGET}
                          PUBLIC
                            ${MAILCORE2_PUBLIC_HEADERS_DIR}
                          PRIVATE 
                            ${async_includes}
                            ${core_includes}
                            ${objc_includes}
)

if(WIN32)
  
  # mailcore2

  target_compile_options(${MAILCORE2_LIB_TARGET} PRIVATE /GS- /Oy /Gw /Gy /GR -fblocks)
  target_link_options(${MAILCORE2_LIB_TARGET} PRIVATE /INCREMENTAL:NO)
  target_compile_definitions(${MAILCORE2_LIB_TARGET}
                            PRIVATE
                              MAILCORE_DLL
                              ZLIB_DLL
                              _WINDLL
                              _CRT_SECURE_NO_WARNINGS
                              _SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS
                              _UNICODE
                              UNICODE)
  
  target_link_libraries(${MAILCORE2_LIB_TARGET}
                        PRIVATE
                          ${LIBETPAN_LIBRARY}
                          ${CTEMPLATE_LIBRARY}
                          ${TIDY_LIBRARY}
                          ${LIBXML_LIBRARY}
                          ${OPENSSL_CRYPTO_LIBRARY}
                          ${ZLIB_LIBRARY}
                          ${ICU4C_UC_LIBRARY}
                          ${ICU4C_IN_LIBRARY}
                          ${DISPATCH_LIBRARY}
                          ${DISPATCH_BLOCKS_LIBRARY}
                          ws2_32
                          Crypt32
  )


  # CMailCore

  include(cmailcore-public-headers)
  include(c)

  add_library(CMailCore ${c_files})

  target_compile_options(CMailCore PRIVATE /GS- /Oy /Gw /Gy /GR -fblocks)
  target_link_options(CMailCore PRIVATE /INCREMENTAL:NO)
  target_compile_definitions(CMailCore
                            PRIVATE
                              CMAILCORE_DLL
                              _UNICODE
                              UNICODE
                              SWIFT
  )
  target_include_directories(CMailCore PRIVATE ${c_includes})

  target_link_libraries(CMailCore 
                        PRIVATE 
                          ${MAILCORE2_LIB_TARGET}
                          ${LIBETPAN_LIBRARY}
                          ${DISPATCH_LIBRARY}
                          ${DISPATCH_BLOCKS_LIBRARY}
  )

  # Install

  install(DIRECTORY
            "${MAILCORE2_PUBLIC_HEADERS_DIR}/MailCore"
          DESTINATION
            include
  )

  install(TARGETS 
            ${MAILCORE2_LIB_TARGET}
            CMailCore
          RUNTIME DESTINATION bin
          ARCHIVE DESTINATION lib
  )

  install(FILES ${CMAILCORE_HEADERS} DESTINATION include/CMailCore)
  install(FILES ${CMAILCORE_MODULEMAP} DESTINATION include/CMailCore)

endif()
