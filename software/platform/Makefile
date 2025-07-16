#################################### Toolchain ###################################
# Compiler
CC                          = gcc

# flags
CFLAGS                      = -g -O0 -x c -I$(PLATFORM_DIR)../ -I$(PLATFORM_COMMON_FILES_DIR)
#################################### 	 	   ####################################

#################################### COMMON FILES ###################################
WORK_DIR                    = work/

PLATFORM_DIR                = ./
PLATFORM_COMMON_FILES_DIR   = $(PLATFORM_DIR)common/
PLATFORM_COMMON_FILES       = $(wildcard $(PLATFORM_COMMON_FILES_DIR)*.cpp $(PLATFORM_COMMON_FILES_DIR)*.c $(PLATFORM_COMMON_FILES_DIR)*.s)
####################################			  ###################################


#################################### LOADER FILES ###################################
LOADER_DIR                  = $(WORK_DIR)loader/
LOADER_BUILD_DIR            = $(LOADER_DIR)build/
LOADER_LOG_DIR              = $(LOADER_DIR)log/

LOADER_FILES                = $(wildcard loader/*.cpp loader/*.c loader/*.s)
LOADER_FIRMWARE             = ../../firmware/loader.hex
####################################			  ###################################


#################################### REPEATER FILES ###################################
REPEATER_DIR                = $(WORK_DIR)repeater/
REPEATER_BUILD_DIR          = $(REPEATER_DIR)build/
REPEATER_LOG_DIR            = $(REPEATER_DIR)log/

REPEATER_FILES              = $(wildcard repeater/*.cpp repeater/*.c repeater/*.s)
REPEATER_FIRMWARE           = ../../firmware/repeater.hex
####################################				###################################


#################################### CYCLEMARK FILES ###################################
CYCLEMARK_DIR                = $(WORK_DIR)cyclemark/
CYCLEMARK_BUILD_DIR          = $(CYCLEMARK_DIR)build/
CYCLEMARK_LOG_DIR            = $(CYCLEMARK_DIR)log/

CYCLEMARK_FILES              = $(wildcard cyclemark/*.cpp cyclemark/*.c cyclemark/*.s)
CYCLEMARK_FIRMWARE           = ../../firmware/cyclemark.hex
####################################				###################################

#################################### WORK TARGET ####################################
.PHONY: work
work:
	@mkdir -p $(WORK_DIR)
####################################			 ####################################

#################################### LOADER TARGET ####################################
.PHONY: loader
loader: work
	@mkdir -p $(LOADER_BUILD_DIR)
	@mkdir -p $(LOADER_LOG_DIR)

	@echo >> $(LOADER_LOG_DIR)log.txt
	@echo Running loader... >> $(LOADER_LOG_DIR)log.txt

	@for source in $(LOADER_FILES); do \
		$(CC) $(CFLAGS) -c $$source -o $(LOADER_BUILD_DIR)$$(basename $$source .c).o; \
	done >> $(LOADER_LOG_DIR)log.txt
	@for source in $(PLATFORM_COMMON_FILES); do \
		$(CC) $(CFLAGS) -c $$source -o $(LOADER_BUILD_DIR)$$(basename $$source .cpp).o; \
	done >> $(LOADER_LOG_DIR)log.txt

	@$(CC) $(LDFLAGS) $(LOADER_BUILD_DIR)*.o -o $(LOADER_BUILD_DIR)software.elf

	sudo $(LOADER_BUILD_DIR)software.elf --logfile $(LOADER_LOG_DIR)log.txt --firmware $(LOADER_FIRMWARE)

.PHONY: clean_loader
clean_loader:
	@rm -rf $(LOADER_DIR)
####################################		 	   ####################################


#################################### REPEATER TARGET ####################################
.PHONY: repeater
repeater: work
	@mkdir -p $(REPEATER_BUILD_DIR)
	@mkdir -p $(REPEATER_LOG_DIR)

	@echo >> $(REPEATER_LOG_DIR)log.txt
	@echo Running repeater... >> $(REPEATER_LOG_DIR)log.txt

	@for source in $(REPEATER_FILES); do \
		$(CC) $(CFLAGS) -c $$source -o $(REPEATER_BUILD_DIR)$$(basename $$source .c).o; \
	done >> $(REPEATER_LOG_DIR)log.txt
	@for source in $(PLATFORM_COMMON_FILES); do \
		$(CC) $(CFLAGS) -c $$source -o $(REPEATER_BUILD_DIR)$$(basename $$source .cpp).o; \
	done >> $(REPEATER_LOG_DIR)log.txt

	echo $(REPEATER_BUILD_DIR)
	$(CC) $(LDFLAGS) $(REPEATER_BUILD_DIR)*.o -o $(REPEATER_BUILD_DIR)software.elf

	sudo $(REPEATER_BUILD_DIR)software.elf --logfile $(REPEATER_LOG_DIR)log.txt --firmware $(REPEATER_FIRMWARE)

.PHONY: clean_repeater
clean_repeater:
	@rm -rf $(REPEATER_DIR)
####################################				 ####################################


#################################### CYCLEMARK TARGET ####################################
.PHONY: cyclemark
cyclemark: work
	@mkdir -p $(CYCLEMARK_BUILD_DIR)
	@mkdir -p $(CYCLEMARK_LOG_DIR)

	@echo >> $(CYCLEMARK_LOG_DIR)log.txt
	@echo Running cyclemark... >> $(CYCLEMARK_LOG_DIR)log.txt

	@for source in $(CYCLEMARK_FILES); do \
		$(CC) $(CFLAGS) -c $$source -o $(CYCLEMARK_BUILD_DIR)$$(basename $$source .c).o; \
	done >> $(CYCLEMARK_LOG_DIR)log.txt
	@for source in $(PLATFORM_COMMON_FILES); do \
		$(CC) $(CFLAGS) -c $$source -o $(CYCLEMARK_BUILD_DIR)$$(basename $$source .cpp).o; \
	done >> $(CYCLEMARK_LOG_DIR)log.txt

	echo $(CYCLEMARK_BUILD_DIR)
	$(CC) $(LDFLAGS) $(CYCLEMARK_BUILD_DIR)*.o -o $(CYCLEMARK_BUILD_DIR)software.elf

	sudo $(CYCLEMARK_BUILD_DIR)software.elf --logfile $(CYCLEMARK_LOG_DIR)log.txt --firmware $(CYCLEMARK_FIRMWARE)

.PHONY: clean_cyclemark
clean_cyclemark:
	@rm -rf $(CYCLEMARK_DIR)
####################################			     ####################################


#################################### CLEAN TARGET ####################################
.PHONY: clean
clean: 
	rm -rf $(WORK_DIR)
####################################			  ####################################