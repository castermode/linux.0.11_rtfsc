file tools/system
target remote :1234

source bindump.py

b main
info b
