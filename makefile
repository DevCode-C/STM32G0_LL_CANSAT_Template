# Firts commit CC = arm-none-eabi
CC = arm-none-eabi
CORE = -mcpu=cortex-m0plus -mthumb -mfloat-abi=soft
TARGET = temp
SYMBOLS = -DSTM32G0B1xx 
# SYMBOLS+= -DSEMIHOSTING
# MOdification
VPATH = App/Src cmsis/startups  lib/Src
INCLUDES = -I App/Inc -I cmsis/core -I cmsis/registers -I lib/Inc

F_SECTIONS = -ffunction-sections -fdata-sections
SPECS_V = -Wl,--gc-sections --specs=rdimon.specs --specs=nano.specs

CFLAGS = -g3 -c $(CORE) -std=gnu99 -Wall -O0 $(F_SECTIONS) $(INCLUDES) $(SYMBOLS)
LDFLAGS = $(CORE) $(SPECS_V) -T cmsis\linker\STM32G0B1RETX_FLASH.ld -Wl,-Map=$(OUTPUT_F)/$(TARGET).map
OBJS_F = Build/Obj
OUTPUT_F = Build

#---Linter ccpcheck flags--------------------------------------------------------------------------
LNFLAGS  = --inline-suppr       # comments to suppress lint warnings
LNFLAGS += --quiet              # spit only useful information
LNFLAGS += --std=c99            # check against C99
LNFLAGS += --template=gcc       # display warning gcc style
LNFLAGS += --force              # evaluate all the #if sentences
LNFLAGS += --platform=unix32    # lint againt a unix32 platform, but we are using arm32
LNFLAGS += --cppcheck-build-dir=Build/cppcheck
SUPPRESLL = 

SRCS  = main.c startup_stm32g0b1xx.c system_stm32g0xx.c 


OBJS = $(SRCS:%.c=$(OBJS_F)/%.o)

all:$(TARGET)

$(TARGET) : $(addprefix $(OUTPUT_F)/,$(TARGET).elf)
	$(CC)-objcopy -Oihex $< Build/$(TARGET).hex
	$(CC)-objdump -S $< > Build/$(TARGET).lst
	$(CC)-size --format=berkeley $<

$(addprefix $(OUTPUT_F)/,$(TARGET).elf): $(OBJS)
	@$(CC)-gcc $(LDFLAGS) -o $@ $^	

$(addprefix $(OBJS_F)/,%.o) : %.c
	@mkdir -p $(OBJS_F)
	@$(CC)-gcc -MD $(CFLAGS) -o $@ $<

$(addprefix $(OBJS_F)/,%.o) : %.s
	@$(CC)-as -c $(CORE) -o $@ $^

-include $(OBJS_F)/*.d

.PHONY: clean flash open debug test_generation test_execution misra docs

test_generation:
	@read -p "Enter Module Name:" module; \
	echo "Making Unit Test for:" $$module;\
	ceedling new Test/UnitTest/$$module 
test_execution:
	@(cd Test/UnitTest && ls)
	@read -p "What module do you need to test:" module; \
	(cd Test/UnitTest/$$module && ceedling test)  
misra:
	@echo "Misra verification:"
	@mkdir -p Build/cppcheck
	@cppcheck --addon=Tools/cppcheck/misra.json --suppressions-list=Tools/cppcheck/.msupress $(LNFLAGS) App/Source App/Include $(SUPPRESLL)
clean:
	@rm -rf Build
	@rm -rf Tools/Doxygen/Documentation
#---Genrete project documentation with doxygen-----------------------------------------------------
docs :
	@mkdir -p Tools/Doxygen/Documentation
	@doxygen Tools/Doxygen/.doxyfile

flash:all
	@openocd -f interface/stlink.cfg -f target/stm32l4x.cfg -c "program Build/$(TARGET).hex verify reset" -c shutdown
open:
	@openocd -f interface/stlink.cfg -f target/stm32l4x.cfg -c "reset_config srst_only srst_nogate"
debug:
	@$(CC)-gdb Build/$(TARGET).elf -q -iex "set auto-load safe-path /"
