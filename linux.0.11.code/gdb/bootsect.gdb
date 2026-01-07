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

# step0
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
info r
print "-------------------------------------------------------------------------"

# step1
si
c
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
info r
print "-------------------------------------------------------------------------"

# step2
si
c
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
info r
print "-------------------------------------------------------------------------"

# step3
si
c
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
print "dump binary memory gdb_output/mem.0x7c00-0x7dff.txt 0x7c00 0x7e00"
dump binary memory gdb_output/mem.0x7c00-0x7dff.txt 0x7c00 0x7e00
!touch gdb_output/mem.md5
!md5sum gdb_output/mem.0x7c00-0x7dff.txt >> gdb_output/mem.md5
!md5sum boot/bootsect >> gdb_output/mem.md5
!echo "" >> gdb_output/mem.md5
info r
print "-------------------------------------------------------------------------"

# step4
si
c
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
info r
print "-------------------------------------------------------------------------"

# step5
si
c
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
print "sectors per track:"
x/2xb 0x90142
info r
print "dump binary memory gdb_output/mem.0x90200-0x909ff.txt 0x90200 0x90a00"
dump binary memory gdb_output/mem.0x90200-0x909ff.txt 0x90200 0x90a00
!md5sum gdb_output/mem.0x90200-0x909ff.txt >> gdb_output/mem.md5
!md5sum boot/setup.4sectors.tmp >> gdb_output/mem.md5
!echo "" >> gdb_output/mem.md5
print "-------------------------------------------------------------------------"

# step6
si
c
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
print "sectors per track(0x90142):"
x/2xb 0x90142
info r
print "-------------------------------------------------------------------------"

# step7
si
c
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
info r
print "-------------------------------------------------------------------------"

# step8
si
c
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
print "root_dev(0x901fc):"
x/2xb 0x901fc
info r
print "dump binary memory gdb_output/mem.0x10000-0x36b20.txt 0x10000 0x36b21"
dump binary memory gdb_output/mem.0x10000-0x36b20.txt 0x10000 0x36b21
!md5sum gdb_output/mem.0x10000-0x36b20.txt >> gdb_output/mem.md5
!md5sum tools/kernel >> gdb_output/mem.md5
print "-------------------------------------------------------------------------"

# step9
si
c
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
info r
print "-------------------------------------------------------------------------"

# step10 jmp into setup
si
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
info r
print "-------------------------------------------------------------------------"

set logging off
