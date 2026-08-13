# Daily-Mobility build automation.
#
#   make routine   the four CSVs -> one JSON resource each under resources/
#   make build     routines + compile the .prg
#   make sim       build + run in the Connect IQ simulator
#   make deploy    build + copy the .prg to a connected watch
#
# All four routines are built into the app and picked on the watch at start. Swap the
# morning one with e.g.  make build ROUTINE_CSV=routine-15min.csv

DEVICE       := fr255m
APP_NAME     := Daily-Mobility
JUNGLE       := monkey.jungle
KEY          := developer_key.der
ROUTINE_CSV  ?= routine.csv
ROUTINE_JSON := resources/routine.json
LEGS_CSV     ?= routine-beine.csv
LEGS_JSON    := resources/routine_legs.json
TRAVEL_CSV   ?= routine-reise.csv
TRAVEL_JSON  := resources/routine_travel.json
SHORT_CSV    ?= routine-kurz.csv
SHORT_JSON   := resources/routine_short.json
BIN          := bin/$(APP_NAME).prg

# Locate the SDK the Connect IQ SDK Manager marked as current.
SDK_HOME := $(shell cat "$(HOME)/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg" 2>/dev/null)
SDK_BIN  := $(SDK_HOME)bin
MONKEYC  := $(SDK_BIN)/monkeyc
MONKEYDO := $(SDK_BIN)/monkeydo
CONNECTIQ := $(SDK_BIN)/connectiq

.PHONY: all routine build sim deploy key clean

all: build

routine: $(ROUTINE_JSON) $(LEGS_JSON) $(TRAVEL_JSON) $(SHORT_JSON)

# Regenerate whenever a CSV or the generator changes. .PHONY-free so it caches.
# The third argument is the name the routine selection screen shows.
$(ROUTINE_JSON): $(ROUTINE_CSV) tools/build_routine.py
	python3 tools/build_routine.py $(ROUTINE_CSV) $(ROUTINE_JSON) "Mobility & Kraft"

$(LEGS_JSON): $(LEGS_CSV) tools/build_routine.py
	python3 tools/build_routine.py $(LEGS_CSV) $(LEGS_JSON) "Beine"

$(TRAVEL_JSON): $(TRAVEL_CSV) tools/build_routine.py
	python3 tools/build_routine.py $(TRAVEL_CSV) $(TRAVEL_JSON) "Unterwegs"

$(SHORT_JSON): $(SHORT_CSV) tools/build_routine.py
	python3 tools/build_routine.py $(SHORT_CSV) $(SHORT_JSON) "Kurzprogramm"

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
	rm -rf bin $(ROUTINE_JSON) $(LEGS_JSON) $(TRAVEL_JSON) $(SHORT_JSON)
