set logging file gdb_output/setup.gdb.output
set logging on
set pagination off
set print repeats 0

file tools/system
target remote :1234


b fork
info b
c

#layout asm
si

x /5i $eip

info reg cs ss esp
echo --------------\n
info reg eip cs eflags esp ss

# return addr 0x68e1

######################################
# come into intr

si
echo --------------\n
info reg cs ss esp

p stack_start

x /20bx $esp

b *0x79ef
c

x /i $eip
echo --------------\n
info reg cs ss esp

######################################
# leave intr

x /20bx $esp
si

info reg cs ss esp

