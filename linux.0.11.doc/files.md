```
linux.0.11.code                          # Linux 0.11 内核源代码根目录
├── bindump.py                           # 二进制文件转储工具脚本
├── boot                                 # 引导加载程序目录
│   ├── bootsect.s                       # 引导扇区代码，BIOS加载的第一段代码(512字节)
│   ├── head.s                           # 保护模式下的初始化代码，设置分页机制
│   ├── Makefile                         # boot目录的编译配置文件
│   └── setup.s                          # 系统设置程序，获取硬件参数并进入保护模式
├── fs                                   # 文件系统目录
│   ├── bitmap.c                         # i节点和块位图操作函数
│   ├── block_dev.c                      # 块设备读写函数
│   ├── buffer.c                         # 缓冲区管理，实现块设备的缓存机制
│   ├── char_dev.c                       # 字符设备读写函数
│   ├── exec.c                           # execve系统调用，执行新程序
│   ├── fcntl.c                          # 文件控制相关系统调用(如fcntl、dup等)
│   ├── file_dev.c                       # 普通文件读写操作
│   ├── file_table.c                     # 文件表管理，维护打开文件的全局表
│   ├── inode.c                          # i节点管理，处理文件元数据
│   ├── ioctl.c                          # 设备输入输出控制系统调用
│   ├── Makefile                         # fs目录的编译配置文件
│   ├── namei.c                          # 文件路径名解析和目录操作
│   ├── open.c                           # 文件打开和关闭系统调用
│   ├── pipe.c                           # 管道实现，进程间通信机制
│   ├── read_write.c                     # 文件读写系统调用
│   ├── stat.c                           # 文件状态获取系统调用
│   ├── super.c                          # 超级块管理，文件系统挂载和卸载
│   └── truncate.c                       # 文件截断操作
├── gdb                                  # GDB调试脚本目录
│   ├── bootsect.gdb                     # 调试引导扇区的GDB脚本
│   ├── bootsect2.gdb                    # 引导扇区调试脚本(第二版)
│   ├── intr.gdb                         # 中断调试脚本
│   ├── kernel.gdb                       # 内核调试脚本
│   ├── main.gdb                         # 主函数调试脚本
│   ├── main2.gdb                        # 主函数调试脚本(第二版)
│   └── setup.gdb                        # setup程序调试脚本
├── hdc-0.11.img.bk                      # 硬盘镜像备份文件
├── include                              # 头文件目录
│   ├── a.out.h                          # a.out可执行文件格式定义
│   ├── asm                              # 汇编相关头文件目录
│   │   ├── io.h                         # 端口I/O操作内联汇编函数
│   │   ├── memory.h                     # 内存操作内联汇编函数
│   │   ├── segment.h                    # 段操作内联汇编函数
│   │   └── system.h                     # 系统级操作内联汇编函数(cli、sti等)
│   ├── const.h                          # 常量定义(缓冲区大小等)
│   ├── ctype.h                          # 字符类型判断宏定义
│   ├── errno.h                          # 错误码定义
│   ├── fcntl.h                          # 文件控制选项定义
│   ├── linux                            # Linux内核专用头文件目录
│   │   ├── config.h                     # 内核配置参数(内存大小、硬盘等)
│   │   ├── fdreg.h                      # 软盘控制器寄存器定义
│   │   ├── fs.h                         # 文件系统数据结构和常量定义
│   │   ├── hdreg.h                      # 硬盘控制器寄存器定义
│   │   ├── head.h                       # 段描述符、页目录等初始化数据
│   │   ├── kernel.h                     # 内核常用函数声明
│   │   ├── mm.h                         # 内存管理数据结构和函数声明
│   │   ├── sched.h                      # 进程调度相关数据结构(task_struct等)
│   │   ├── sys.h                        # 系统调用函数指针表声明
│   │   └── tty.h                        # 终端I/O数据结构定义
│   ├── signal.h                         # 信号处理相关定义
│   ├── stdarg.h                         # 可变参数列表宏定义
│   ├── stddef.h                         # 标准类型定义(NULL、size_t等)
│   ├── string.h                         # 字符串操作函数声明
│   ├── sys                              # 系统调用相关头文件目录
│   │   ├── stat.h                       # 文件状态结构定义
│   │   ├── times.h                      # 进程时间结构定义
│   │   ├── types.h                      # 基本系统数据类型定义
│   │   ├── utsname.h                    # 系统名称结构定义
│   │   └── wait.h                       # 进程等待选项定义
│   ├── termios.h                        # 终端I/O控制定义
│   ├── time.h                           # 时间类型和函数声明
│   ├── unistd.h                         # Unix标准函数和系统调用声明
│   └── utime.h                          # 文件时间修改函数声明
├── init                                 # 初始化代码目录
│   └── main.c                           # 内核初始化主函数，系统启动入口
├── kernel                               # 内核核心功能目录
│   ├── asm.s                            # 汇编实现的底层函数(系统调用入口等)
│   ├── blk_drv                          # 块设备驱动目录
│   │   ├── blk.h                        # 块设备驱动头文件
│   │   ├── floppy.c                     # 软盘驱动程序
│   │   ├── hd.c                         # 硬盘驱动程序
│   │   ├── ll_rw_blk.c                  # 底层块设备读写函数
│   │   ├── Makefile                     # 块设备驱动编译配置
│   │   └── ramdisk.c                    # 内存虚拟盘驱动
│   ├── chr_drv                          # 字符设备驱动目录
│   │   ├── console.c                    # 控制台驱动，显示输出
│   │   ├── kb.S                         # 键盘中断处理汇编代码
│   │   ├── Makefile                     # 字符设备驱动编译配置
│   │   ├── rs_io.s                      # 串口中断处理汇编代码
│   │   ├── serial.c                     # 串口驱动程序
│   │   ├── tty_io.c                     # 终端I/O处理，tty核心层
│   │   └── tty_ioctl.c                  # 终端I/O控制函数
│   ├── exit.c                           # 进程退出和终止处理
│   ├── fork.c                           # 进程创建(fork系统调用实现)
│   ├── Makefile                         # kernel目录的编译配置文件
│   ├── math                             # 数学协处理器目录
│   │   ├── Makefile                     # math目录编译配置
│   │   └── math_emulate.c               # 数学协处理器仿真(未完全实现)
│   ├── mktime.c                         # 时间换算函数，计算从1970年开始的秒数
│   ├── panic.c                          # 内核严重错误处理函数
│   ├── printk.c                         # 内核打印函数，格式化输出
│   ├── sched.c                          # 进程调度核心代码，时间片轮转算法
│   ├── signal.c                         # 信号处理机制实现
│   ├── sys.c                            # 系统调用实现(如setuid、alarm等)
│   ├── system_call.s                    # 系统调用总入口汇编代码(int 0x80)
│   ├── traps.c                          # 异常(陷阱)和故障处理
│   ├── vsprintf.c                       # 格式化字符串输出函数
│   └── who.c                            # 打印内核版本信息
├── lib                                  # 用户态库函数目录
│   ├── _exit.c                          # 进程退出库函数
│   ├── close.c                          # 关闭文件库函数
│   ├── ctype.c                          # 字符类型判断函数实现
│   ├── dup.c                            # 文件描述符复制库函数
│   ├── errno.c                          # 全局错误码变量定义
│   ├── execve.c                         # 执行新程序库函数
│   ├── Makefile                         # lib目录的编译配置文件
│   ├── malloc.c                         # 动态内存分配函数
│   ├── open.c                           # 打开文件库函数
│   ├── setsid.c                         # 设置会话ID库函数
│   ├── string.c                         # 字符串操作函数实现
│   ├── wait.c                           # 等待子进程库函数
│   └── write.c                          # 写文件库函数
├── Makefile                             # 项目主编译配置文件
├── Makefile.header                      # Makefile通用头文件，定义编译选项
├── mm                                   # 内存管理目录
│   ├── Makefile                         # mm目录的编译配置文件
│   ├── memory.c                         # 内存管理核心代码，分页机制和内存映射
│   └── page.s                           # 页异常处理汇编代码(缺页中断)
├── README.md                            # 项目说明文档
├── readme.old                           # 旧版说明文档
└── tools                                # 工具目录
    ├── bochs                            # Bochs虚拟机相关配置
    │   ├── bochsrc                      # Bochs配置文件目录
    │   │   ├── bochsrc-hd-dbg.bxrc      # 硬盘调试模式配置
    │   │   └── bochsrc-hd.bxrc          # 硬盘运行模式配置
    │   └── README                       # Bochs工具说明
    ├── build.sh                         # 构建脚本
    ├── gdb                              # GDB调试器(预编译版本)
    └── README                           # 工具目录说明

18 directories, 119 files
```