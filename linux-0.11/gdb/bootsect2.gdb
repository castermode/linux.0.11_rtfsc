set logging file gdb_output/bootsect.gdb.output
set logging on
set pagination off
set print repeats 0

file boot/bootsect.tmp
target remote :1234

# step0
# bios
#b *0xfffffff0

# step1
# boot sector
b *0x7c00

# step2
# jmp new pos
b *0x7c18

# step3
# reset seg, stack
b *0x9001d

# step4
# load setup to 0x92000
b *0x90028

# step5
# get nr of sectors/track
b *0x90042

# step6
# print msg
b *0x90055

# step7
# load kernel to 0x10000
b *0x90069

# step8
# get params
b *0x90074

# step9
# jmp to setup
b *0x90098

info b

