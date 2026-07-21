#use gdb -tui as debugger
# Compiler Settings
CC = gcc
C_FLAGS = -g -O0 -std=gnu99 -lsystemd

# File Paths
EPOLL_MNGR_PATH = src/epoll_manager.c
TARGET = bin/epoll_manager

all: $(TARGET)

$(TARGET): $(EPOLL_MNGR_PATH)
	mkdir -p bin
	echo "Compiling epoll_manager.c..."
	$(CC) $(C_FLAGS)  $(EPOLL_MNGR_PATH) -o $(TARGET)

clean: 
	rm -f $(TARGET)

