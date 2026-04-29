include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(concurrency_practice_supports_sanitizers)
  # Emscripten doesn't support sanitizers
  if(EMSCRIPTEN)
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  elseif((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(concurrency_practice_setup_options)
  option(concurrency_practice_ENABLE_HARDENING "Enable hardening" ON)
  option(concurrency_practice_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    concurrency_practice_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    concurrency_practice_ENABLE_HARDENING
    OFF)

  concurrency_practice_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR concurrency_practice_PACKAGING_MAINTAINER_MODE)
    option(concurrency_practice_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(concurrency_practice_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(concurrency_practice_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(concurrency_practice_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(concurrency_practice_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(concurrency_practice_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(concurrency_practice_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(concurrency_practice_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(concurrency_practice_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(concurrency_practice_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(concurrency_practice_ENABLE_PCH "Enable precompiled headers" OFF)
    option(concurrency_practice_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(concurrency_practice_ENABLE_IPO "Enable IPO/LTO" ON)
    option(concurrency_practice_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(concurrency_practice_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(concurrency_practice_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(concurrency_practice_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(concurrency_practice_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(concurrency_practice_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(concurrency_practice_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(concurrency_practice_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(concurrency_practice_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(concurrency_practice_ENABLE_PCH "Enable precompiled headers" OFF)
    option(concurrency_practice_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      concurrency_practice_ENABLE_IPO
      concurrency_practice_WARNINGS_AS_ERRORS
      concurrency_practice_ENABLE_SANITIZER_ADDRESS
      concurrency_practice_ENABLE_SANITIZER_LEAK
      concurrency_practice_ENABLE_SANITIZER_UNDEFINED
      concurrency_practice_ENABLE_SANITIZER_THREAD
      concurrency_practice_ENABLE_SANITIZER_MEMORY
      concurrency_practice_ENABLE_UNITY_BUILD
      concurrency_practice_ENABLE_CLANG_TIDY
      concurrency_practice_ENABLE_CPPCHECK
      concurrency_practice_ENABLE_COVERAGE
      concurrency_practice_ENABLE_PCH
      concurrency_practice_ENABLE_CACHE)
  endif()

  concurrency_practice_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (concurrency_practice_ENABLE_SANITIZER_ADDRESS OR concurrency_practice_ENABLE_SANITIZER_THREAD OR concurrency_practice_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(concurrency_practice_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(concurrency_practice_global_options)
  if(concurrency_practice_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    concurrency_practice_enable_ipo()
  endif()

  concurrency_practice_supports_sanitizers()

  if(concurrency_practice_ENABLE_HARDENING AND concurrency_practice_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR concurrency_practice_ENABLE_SANITIZER_UNDEFINED
       OR concurrency_practice_ENABLE_SANITIZER_ADDRESS
       OR concurrency_practice_ENABLE_SANITIZER_THREAD
       OR concurrency_practice_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${concurrency_practice_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${concurrency_practice_ENABLE_SANITIZER_UNDEFINED}")
    concurrency_practice_enable_hardening(concurrency_practice_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(concurrency_practice_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(concurrency_practice_warnings INTERFACE)
  add_library(concurrency_practice_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  concurrency_practice_set_project_warnings(
    concurrency_practice_warnings
    ${concurrency_practice_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    concurrency_practice_enable_sanitizers(
      concurrency_practice_options
      ${concurrency_practice_ENABLE_SANITIZER_ADDRESS}
      ${concurrency_practice_ENABLE_SANITIZER_LEAK}
      ${concurrency_practice_ENABLE_SANITIZER_UNDEFINED}
      ${concurrency_practice_ENABLE_SANITIZER_THREAD}
      ${concurrency_practice_ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(concurrency_practice_options PROPERTIES UNITY_BUILD ${concurrency_practice_ENABLE_UNITY_BUILD})

  if(concurrency_practice_ENABLE_PCH)
    target_precompile_headers(
      concurrency_practice_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(concurrency_practice_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    concurrency_practice_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(concurrency_practice_ENABLE_CLANG_TIDY)
    concurrency_practice_enable_clang_tidy(concurrency_practice_options ${concurrency_practice_WARNINGS_AS_ERRORS})
  endif()

  if(concurrency_practice_ENABLE_CPPCHECK)
    concurrency_practice_enable_cppcheck(${concurrency_practice_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(concurrency_practice_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    concurrency_practice_enable_coverage(concurrency_practice_options)
  endif()

  if(concurrency_practice_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(concurrency_practice_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(concurrency_practice_ENABLE_HARDENING AND NOT concurrency_practice_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR concurrency_practice_ENABLE_SANITIZER_UNDEFINED
       OR concurrency_practice_ENABLE_SANITIZER_ADDRESS
       OR concurrency_practice_ENABLE_SANITIZER_THREAD
       OR concurrency_practice_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    concurrency_practice_enable_hardening(concurrency_practice_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
