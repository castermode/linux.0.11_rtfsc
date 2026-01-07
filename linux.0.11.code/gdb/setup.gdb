set logging file gdb_output/setup.gdb.output
set logging on
set pagination off 
set print repeats 0

file boot/setup.tmp
target remote :1234

# step0
# bios
#b *0xffff0

# step1
# load system parameters
b *0x90200

# step2
# move kernel to 0x00000
b *0x90333

# step3
# init protect mode
b *0x9034f

# step4
# jmp to head, enter protect mode
b *0x903b5

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
print "cursor pos:"
x/2xb 0x90000
print "memory size >= 0x100000 (KB):"
x/2xb 0x90002
print "display page number:"
x/2xb 0x90004
print "display mode:"
x/2xb 0x90006
print "col:"
x/1xb 0x90007
print "???:"
x/2xb 0x90008
print "display memory(0x00-64K, 0x01-128K, 0x02-192K, 0x03-256K):"
x/1xb 0x9000a
print "display state:"
x/1xb 0x9000b
print "display card parameter:"
x/2xb 0x9000c
print "screen line number"
x/1xb 0x9000e
print "screen column number:"
x/1xb 0x9000f
print "hard disk1 parameter:"
x/16xb 0x90080
print "hard disk2 parameter:"
x/16xb 0x90090
print "root dev number:"
x/2xb 0x901fc
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
print "dump binary memory gdb_output/mem.0x00000-0x26b20.txt 0x00000 0x26b21"
dump binary memory gdb_output/mem.0x00000-0x26b20.txt 0x00000 0x26b21
print "dump binary memory gdb_output/mem.0x00000-0x7ffff.txt 0x00000 0x80000"
dump binary memory gdb_output/mem.0x00000-0x7ffff.txt 0x00000 0x80000
!touch gdb_output/mem.md5
!md5sum gdb_output/mem.0x00000-0x26b20.txt >> gdb_output/mem.md5
!md5sum tools/kernel >> gdb_output/mem.md5
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

# step4
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $cs*16+$eip
print "stack addr:"
print $ss*16+$esp
print "gdt:"
x/2048xb 0x903c5
info r
print "-------------------------------------------------------------------------"

# step5
si
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print 0x00000+$eip
print "stack addr:"
print $ss*16+$esp
info r
set logging off
