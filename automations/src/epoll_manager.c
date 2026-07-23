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
#define STATE_ARR_SIZE 4

// Constants
const int EPOLL_TIMEOUT = -1;

// Statics
static const char *BT_AUTOMATION_SCRIPT_PATH =
    "/home/luciano/dotfiles/automations/bin/bluetooth_headphones_automation.sh";
static const char *BLUETOOTH_MATCH_FILTERS = "type='signal',sender='org.bluez'";

// ensure alias and dev_path are inputted EXACTLY as the commands listed below
struct known_device {
  const char *alias;     // bluetoothctl devices
  const char *dev_path;  // busctl tree org.bluez
  int connection_status; // 0 is off; 1, on. (-1 default)
};

// device must be in watchlist to trigger automation
struct known_device device_watchlist[] = {
    {"MOONDROP EDGE", "/org/bluez/hci0/dev_41_42_32_30_6A_B8", -1},
    {"onn Bone Conduction", "/org/bluez/hci0/dev_28_04_C6_93_DE_E6", -1}};

/**
 * @brief executes the device automation bash script. It passes the device path
 * and connection status as arguments to the bash script.
 *
 * @param script_path is a relative to bin from /src
 * @param device_path see known_device struct
 * @param device_alias see known_device struct
 * @param state 0 is disconnected; 1, connected. (-1 by default/)
 */
void exec_dev_automation_bash(const char *script_path, const char *device_path,
                              const char *device_alias, int state) {
  char cur_dev_state[STATE_ARR_SIZE];
  snprintf(cur_dev_state, sizeof(cur_dev_state), "%d", state);

  pid_t pid = fork();

  switch (pid) {
    case -1:
      perror("Failed to fork.");
      break;
    case 0:
      execl("/bin/bash", "bash", script_path, device_path, device_alias,
            cur_dev_state, (char *)NULL);
      perror("execl failed.");
      _exit(-1);
      break;
    default: {
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
  event.data.fd = bus_fd; // We are watching the D-Bus file descriptor

  // 3. Add STDIN to the epoll watch list
  if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, bus_fd, &event) == -1) {
    perror("Failed to add bus_fd to epoll file descriptor. ");
    return -1;
  }

  // Array to hold the events that get triggered
  struct epoll_event events[MAX_EVENTS];

  printf("Going to sleep. Waiting for Bluetooth events!\n");

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

            int target_device_index = -1;
            int num_devices =
                sizeof(device_watchlist) / sizeof(device_watchlist[0]);

            for (int i = 0; i < num_devices; i++) {
              if (strcmp(path, device_watchlist[i].dev_path) == 0) {
                target_device_index = i;
                break;
              }
            }

            // failed to find a matching path, skip parsing
            if (target_device_index == -1) {
              sd_bus_message_unref(msg);
              continue;
            }

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
                  int is_connected = -1;
                  sd_bus_message_read(msg, "b", &is_connected);
                  sd_bus_message_exit_container(msg);

                  if (is_connected !=
                      device_watchlist[target_device_index].connection_status) {

                    printf("%s Connection Status: %d\n",
                           device_watchlist[target_device_index].alias,
                           is_connected);
                    exec_dev_automation_bash(
                        BT_AUTOMATION_SCRIPT_PATH, path,
                        device_watchlist[target_device_index].alias,
                        is_connected);
                    device_watchlist[target_device_index].connection_status =
                        is_connected;
                  }
                } else {
                  sd_bus_message_skip(msg, "v");
                }
                sd_bus_message_exit_container(msg); // Exit DICT_ENTRY
              }
              sd_bus_message_exit_container(msg); // Exit ARRAY
            }
          }
          sd_bus_message_unref(msg);
        }
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
