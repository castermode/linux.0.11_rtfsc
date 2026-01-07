include ../Makefile.header

LDFLAGS	+= -Ttext 0

all: bootsect setup

bootsect: bootsect.s
	@$(AS) -o bootsect.o bootsect.s -g
	@$(LD) $(LDFLAGS) -o bootsect bootsect.o
	cp bootsect bootsect.tmp
	@$(OBJCOPY) -R .pdr -R .comment -R.note -S -O binary bootsect


setup: setup.s
	@$(AS) -o setup.o setup.s -g
	@$(LD) $(LDFLAGS) -o setup setup.o
	cp setup setup.tmp
	@$(OBJCOPY) -R .pdr -R .comment -R.note -S -O binary setup

head.o: head.s
	@$(AS) -o head.o head.s -g

clean:
	@rm -f bootsect bootsect.o setup setup.o head.o bootsect.tmp setup.tmp
