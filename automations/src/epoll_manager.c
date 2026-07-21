#include <stdio.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/wait.h>
#include <systemd/sd-bus-protocol.h>
#include <systemd/sd-bus.h>
#include <unistd.h>

// Define Macros
#define MAX_EVENTS 4
#define EPOLL_CREATE_FLAG 0

// Constants
const int EPOLL_TIMEOUT = -1;
const char *BASH_SCRIPT_PATH = "./bin/dummy_bash.sh";
const char *BLUETOOTH_MATCH_FILTERS = "type='signal',sender='org.bluez'";

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
  // We need a pointer to hold the D-Bus connection object.
  // We initialize it to NULL for safety.
  sd_bus *bus = NULL;

  // 1. Open the system bus connection
  int open_bus_status;
  if ((open_bus_status = sd_bus_open_system(&bus)) < 0) {
    fprintf(stderr, "Failed to open system bus. Error: %s\n",
            strerror(-open_bus_status));
    return -1;
  }

  // 2. Extract the file descriptor
  int bus_fd;
  if ((bus_fd = sd_bus_get_fd(bus)) < 0) {
    fprintf(stderr, "Failed to return a file descriptor. Error: %s\n",
            strerror(-bus_fd));
    sd_bus_unref(bus);
    return -1;
  }

  printf("Successfully connected to system bus (FD: %d)\n", bus_fd);

  // Adding Match Rule
  int add_match_status;
  if ((add_match_status = sd_bus_add_match(bus, NULL, BLUETOOTH_MATCH_FILTERS,
                                           NULL, NULL)) < 0) {
    fprintf(
        stderr,
        "Failed to add bluetooth match filters to the system bus. Error: %s\n",
        strerror(-add_match_status));
    sd_bus_unref(bus);
    return -1;
  }

  // 1. Create the epoll instance
  int epoll_fd;
  if ((epoll_fd = epoll_create1(EPOLL_CREATE_FLAG)) == -1) {
    perror("Failed to create epoll file descriptor");
    return -1;
  }

  // 2. Configure the event we want to watch
  struct epoll_event event;
  event.events = EPOLLIN; // We want to wake up when data comes IN
  event.data.fd = bus_fd; // We are watching the standard input (keyboard)

  // 3. Add STDIN to the epoll watch list

  if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, bus_fd, &event) == -1) {
    perror("Failed to add bus_fd to epoll file descriptor. ");
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
      if (events[i].data.fd == bus_fd) {

        // Processing D-Bus Messages
        sd_bus_message *msg = NULL;

        while (sd_bus_process(bus, &msg) > 0) {
          if (!msg) { // ignore if null
            continue;
          }

          const char *path = sd_bus_message_get_path(msg);
          const char *interface = sd_bus_message_get_interface(msg);
          const char *member = sd_bus_message_get_member(msg);

          if (path && interface && member) {
            if (strcmp(member, "PropertiesChanged") == 0) { // exact match
              const char *changed_interface = NULL;
              sd_bus_message_read(msg, "s", &changed_interface);
              sd_bus_message_enter_container(msg, SD_BUS_TYPE_ARRAY, "{sv}");

              while (sd_bus_message_enter_container(msg, SD_BUS_TYPE_DICT_ENTRY,
                                                    "sv") > 0) {
                const char *key = NULL;
                sd_bus_message_read(msg, "s", &key);

                if (strcmp(key, "Connected") == 0) {
                  sd_bus_message_enter_container(msg, SD_BUS_TYPE_VARIANT, "b");
                  int is_connected = 1;
                  sd_bus_message_read(msg, "b", &is_connected);
                  printf("Device connection stage changed to: %d\n",
                         is_connected);
                  sd_bus_message_exit_container(msg);

                } else {
                  sd_bus_message_skip(msg, "v");
                }
                sd_bus_message_exit_container(msg);
              }
              sd_bus_message_exit_container(msg);
            }
          }

          sd_bus_message_unref(msg);
        }
        execute_bash_script(BASH_SCRIPT_PATH);
      }
    }
  }

  if (close(epoll_fd) == -1) {
    perror("Unable to close epoll file descriptor.");
    return -1;
  }

  sd_bus_unref(bus);

  return 0;
}
