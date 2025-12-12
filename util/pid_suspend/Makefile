CC = clang
CFLAGS = -Wall -Wextra -O2

TARGET = pid_suspend

.PHONY: all clean

all: $(TARGET)

$(TARGET): pid_suspend.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)
