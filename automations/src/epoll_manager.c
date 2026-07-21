#include <stdio.h>
#include <sys/epoll.h>
#include <sys/wait.h>
#include <systemd/sd-bus.h>
#include <unistd.h>

// Define Macros
#define MAX_EVENTS 4
#define EPOLL_CREATE_FLAG 0

// Constants
const int EPOLL_TIMEOUT = -1;
const char *BASH_SCRIPT_PATH = "./bin/dummy_bash.sh";

// Helper Functions
void execute_bash_script(const char *script_path) {
  printf("Spawning child process to run script...\n");

  pid_t pid = fork();

  switch (pid) {
  case -1: // error
    perror("Failed to fork.");
    break;
  case 0: // child process
    execl(script_path, (char *)NULL);
    perror("execl failed.");
    _exit(-1);
    break;
  default: { // parent process
    int child_status;
    waitpid(pid, &child_status, 0);
    printf("Child process finished. Going back to sleep.\n");
    break;
  }
  }
}

int main() {
  printf("Starting epoll manager...\n");

  // 1. Create the epoll instance
  int epoll_fd;
  if ((epoll_fd = epoll_create1(EPOLL_CREATE_FLAG)) == -1) {
    perror("Failed to create epoll file descriptor");
    return -1;
  }

  // 2. Configure the event we want to watch
  struct epoll_event event;
  event.events = EPOLLIN;       // We want to wake up when data comes IN
  event.data.fd = STDIN_FILENO; // We are watching the standard input (keyboard)

  // 3. Add STDIN to the epoll watch list

  if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, STDIN_FILENO, &event) == -1) {
    perror("Failed to add STDIN_FILENO to epoll file descriptor. ");
    return -1;
  }
  // Array to hold the events that get triggered
  struct epoll_event events[MAX_EVENTS];

  printf("Going to sleep. Press Enter to wake me up!\n");

  // 4. The Infinite Event Loop
  while (1) {
    int event_count;
    if ((event_count =
             epoll_wait(epoll_fd, events, MAX_EVENTS, EPOLL_TIMEOUT)) == -1) {
      perror("Failed to return number of events triggered.");
      break;
    }

    // Loop through all triggered events (right now, it will only ever be 1)
    for (int i = 0; i < event_count; i++) {
      if (events[i].data.fd == STDIN_FILENO) {
        printf("Wake up! You pressed Enter.\n");

        // Read the input buffer to clear it, otherwise epoll will immediately
        // trigger again on the next loop (Level-Triggered behavior!)
        char buffer[256];

        if (read(STDIN_FILENO, buffer, sizeof(buffer)) == -1) {
          perror("Unable to read STDIN_FILENO into buffer.");
          continue; // continue because loop can still work for the next buffer
        }

        execute_bash_script(BASH_SCRIPT_PATH);
      }
    }
  }

  if (close(epoll_fd) == -1) {
    perror("Unable to close epoll file descriptor.");
    return -1;
  }

  return 0;
}
