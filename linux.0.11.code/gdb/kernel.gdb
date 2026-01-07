set logging file gdb_output/kernel.gdb.output
set logging on
set pagination off 
set print repeats 0

file tools/system
target remote :1234

# step0
# bios
#b *0xffff0

# step1
# jmp to head, here is in setup
b *0x903b5

# step2
# si
# to head

# step3
# set x87
b *0x42

# step4
b after_page_tables

# step5
b setup_paging

# step6
b *0x54a6

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
c
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $eip
print "stack addr:"
print $esp
info r
print "-------------------------------------------------------------------------"

# step2
si
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $eip
print "stack addr:"
print $esp
print "stack_start:"
print stack_start
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
print $eip
print "stack addr:"
print $esp
print "gdt:"
x/2048xb 0x5cb8
print "ignore_int:"
print ignore_int
print "idt:"
x/2048xb 0x54b8
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
print $eip
print "stack addr:"
print $esp
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
print $eip
print "stack addr:"
print $esp
print "main:"
print main
print "some stack data"
x/16xb $esp
info r
print "-------------------------------------------------------------------------"

# step6
si
c
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $eip
print "stack addr:"
print $esp
print "pdt"
x/4096xb 0x00000
print "pgt0"
x/4096xb 0x01000
print "pgt1"
x/4096xb 0x02000
print "pgt2"
x/4096xb 0x03000
print "pgt3"
x/4096xb 0x04000
info r
print "-------------------------------------------------------------------------"

# step7
si
info r cs
info r eip
info r ss
info r sp
print "code addr:"
print $eip
print "stack addr:"
print $esp
print "main:"
print main

set logging off
