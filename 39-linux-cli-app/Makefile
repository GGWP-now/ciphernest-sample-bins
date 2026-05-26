CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra
OUT ?= build

.PHONY: all clean run

all: $(OUT)/linux_cli_app

$(OUT):
	mkdir -p $(OUT)

$(OUT)/linux_cli_app: main.c | $(OUT)
	$(CC) $(CFLAGS) -o $@ main.c

run: all
	$(OUT)/linux_cli_app 128

clean:
	rm -rf $(OUT)
