# Daily-Mobility build automation.
#
#   make routine   CSV -> resources/routine.json
#   make build     routine + compile the .prg
#   make sim       build + run in the Connect IQ simulator
#   make deploy    build + copy the .prg to a connected watch
#
# Swap the active routine with e.g.  make build ROUTINE_CSV=routine-15min.csv

DEVICE       := fr255m
APP_NAME     := Daily-Mobility
JUNGLE       := monkey.jungle
KEY          := developer_key.der
ROUTINE_CSV  ?= routine.csv
ROUTINE_JSON := resources/routine.json
BIN          := bin/$(APP_NAME).prg

# Locate the SDK the Connect IQ SDK Manager marked as current.
SDK_HOME := $(shell cat "$(HOME)/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg" 2>/dev/null)
SDK_BIN  := $(SDK_HOME)bin
MONKEYC  := $(SDK_BIN)/monkeyc
MONKEYDO := $(SDK_BIN)/monkeydo
CONNECTIQ := $(SDK_BIN)/connectiq

.PHONY: all routine build sim deploy key clean

all: build

routine: $(ROUTINE_JSON)

# Regenerate whenever the CSV or the generator changes. .PHONY-free so it caches.
$(ROUTINE_JSON): $(ROUTINE_CSV) tools/build_routine.py
	python3 tools/build_routine.py $(ROUTINE_CSV) $(ROUTINE_JSON)

key: $(KEY)

$(KEY):
	openssl genrsa -out developer_key.pem 4096
	openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out $(KEY) -nocrypt

build: routine $(KEY)
	@mkdir -p bin
	"$(MONKEYC)" -d $(DEVICE) -f $(JUNGLE) -o $(BIN) -y $(KEY)
	@echo "Built $(BIN)"

sim: build
	@echo "Launching Connect IQ simulator..."
	@"$(CONNECTIQ)" >/dev/null 2>&1 &
	@sleep 3
	"$(MONKEYDO)" $(BIN) $(DEVICE)

deploy: build
	@if [ -d /Volumes/GARMIN ]; then \
		mkdir -p /Volumes/GARMIN/GARMIN/APPS; \
		cp $(BIN) /Volumes/GARMIN/GARMIN/APPS/; \
		echo "Copied $(BIN) to /Volumes/GARMIN/GARMIN/APPS/. Eject the watch, then disconnect."; \
	else \
		echo "Watch not found at /Volumes/GARMIN."; \
		echo "Set the watch USB mode to Garmin (Settings > System > USB Mode), connect it, and retry."; \
		echo "If it still doesn't mount, use OpenMTP to copy $(BIN) into GARMIN/APPS/."; \
		exit 1; \
	fi

clean:
	rm -rf bin $(ROUTINE_JSON)
