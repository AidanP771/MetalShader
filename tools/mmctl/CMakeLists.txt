# mmctl: command-line client for the core's dev control socket.

add_executable(mmctl src/mmctl.c)
target_link_libraries(mmctl PRIVATE mm_common)
