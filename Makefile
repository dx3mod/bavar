ARTIFACTS_PATH=/tmp/bavar-artifacts

build:
	dune build

artifacts:
	dune build --profile=release

	rm -rf $(ARTIFACTS_PATH)
	mkdir $(ARTIFACTS_PATH)
	mkdir $(ARTIFACTS_PATH)/bin

	cp --no-preserve=mode,ownershi _build/default/bin/main.exe $(ARTIFACTS_PATH)
	strip $(ARTIFACTS_PATH)/main.exe
	chmod +x $(ARTIFACTS_PATH)/main.exe

	mv $(ARTIFACTS_PATH)/main.exe $(ARTIFACTS_PATH)/bin/bavar
	
	cp	tools/bmp2bit $(ARTIFACTS_PATH)/bin/bavar-bmp2bit

	COMMAND_OUTPUT_INSTALLATION_BASH=1 $(ARTIFACTS_PATH)/bin/bavar > $(ARTIFACTS_PATH)/bavar-completion.sh

