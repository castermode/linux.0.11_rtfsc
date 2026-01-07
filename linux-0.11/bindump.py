import gdb

class BinDumpCommand(gdb.Command):
    def __init__(self):
        super(BinDumpCommand, self).__init__("bindump", gdb.COMMAND_DATA)
    
    def invoke(self, arg, from_tty):
        args = gdb.string_to_argv(arg)
        if len(args) != 1:
            print("Usage: bindump <variable>")
            return

        var = gdb.parse_and_eval(args[0])
        val = int(var)
        bin_str = bin(val)[2:].zfill(var.type.sizeof * 8)
        
        print("Binary dump of", var)
        print(bin_str)

BinDumpCommand()
