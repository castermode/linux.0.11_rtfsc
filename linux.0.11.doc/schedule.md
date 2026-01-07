# Linux 0.11 进程调度详解

## 目录
- [1. 概述](#1-概述)
- [2. 关键数据结构](#2-关键数据结构)
- [3. 调度算法](#3-调度算法)
- [4. 时钟中断与调度触发](#4-时钟中断与调度触发)
- [5. schedule() 函数详解](#5-schedule-函数详解)
- [6. 任务切换 switch_to](#6-任务切换-switch_to)
- [7. 睡眠与唤醒机制](#7-睡眠与唤醒机制)
- [8. 完整执行流程示例](#8-完整执行流程示例)

---

## 1. 概述

Linux 0.11 采用了**基于时间片的抢占式调度**机制，这是一个非常经典的调度算法。调度器的核心目标是：
- 给每个进程公平的 CPU 时间
- 保证系统响应性
- 实现简单高效

**调度触发时机：**
1. **时钟中断**：每 10ms 触发一次（HZ=100）
2. **系统调用返回**：检查是否需要重新调度
3. **进程主动睡眠**：调用 sleep_on() 或 pause()
4. **进程等待资源**：如等待 I/O

**核心文件：**
- `kernel/sched.c` - 调度核心实现
- `kernel/system_call.s` - 系统调用和中断处理
- `include/linux/sched.h` - 进程控制块定义

---

## 2. 关键数据结构

### 2.1 进程控制块 (task_struct)

每个进程都有一个 `task_struct` 结构，包含进程的所有信息：

```c
struct task_struct {
    // 调度相关字段
    long state;          // 进程状态：RUNNING/INTERRUPTIBLE/UNINTERRUPTIBLE/ZOMBIE/STOPPED
    long counter;        // 剩余时间片（滴答数）
    long priority;       // 优先级（基础时间片）
    long signal;         // 信号位图
    
    // 进程标识
    long pid;            // 进程 ID
    long father;         // 父进程 ID
    
    // 时间统计
    long utime;          // 用户态运行时间
    long stime;          // 内核态运行时间
    long start_time;     // 进程启动时间
    
    // TSS 和 LDT
    struct tss_struct tss;    // 任务状态段，保存 CPU 寄存器
    struct desc_struct ldt[3]; // 局部描述符表
    
    // ... 其他字段（文件、内存等）
};
```

**关键字段说明：**

- **state**: 进程状态
  - `TASK_RUNNING (0)` - 可运行（就绪或正在运行）
  - `TASK_INTERRUPTIBLE (1)` - 可中断睡眠（可被信号唤醒）
  - `TASK_UNINTERRUPTIBLE (2)` - 不可中断睡眠（只能显式唤醒）
  - `TASK_ZOMBIE (3)` - 僵尸状态
  - `TASK_STOPPED (4)` - 停止状态

- **counter**: 当前进程剩余的时间片，初始值等于 priority
  - 每次时钟中断递减 1
  - 减到 0 时触发调度
  - 这是调度决策的关键依据

- **priority**: 进程优先级，决定分配的时间片大小
  - 初始值通常为 15
  - priority 越大，获得的 CPU 时间越多

### 2.2 全局变量

```c
struct task_struct *task[NR_TASKS];    // 任务数组，最多 64 个进程
struct task_struct *current;            // 当前正在运行的进程
long volatile jiffies;                  // 系统启动以来的滴答数（10ms/滴答）
```

### 2.3 TSS (Task State Segment)

TSS 保存了进程的 CPU 上下文，用于任务切换：

```c
struct tss_struct {
    long back_link;
    long esp0;       // 内核栈指针
    long ss0;        // 内核栈段选择符
    long eip;        // 指令指针
    long eflags;     // 标志寄存器
    long eax, ecx, edx, ebx;
    long esp, ebp, esi, edi;
    long es, cs, ss, ds, fs, gs;
    long ldt;        // LDT 选择符
    // ...
};
```

---

## 3. 调度算法

Linux 0.11 使用的是**基于优先级和时间片的调度算法**。

### 3.1 算法原理

调度器选择下一个运行的进程时，遵循以下规则：

1. **只考虑 TASK_RUNNING 状态的进程**
2. **选择 counter 值最大的进程**（counter 表示剩余时间片）
3. **如果所有进程 counter 都为 0**，重新计算所有进程的 counter：
   ```c
   counter = (counter >> 1) + priority
   ```
   - 这个公式很巧妙：没用完的时间片会保留一半，然后加上优先级
   - 这样可以奖励 I/O 密集型进程（它们经常主动放弃 CPU，counter 不会减到 0）

### 3.2 算法特点

**优点：**
- 简单高效，代码少
- 对 I/O 密集型进程友好（响应快）
- 动态调整，公平性好

**缺点：**
- 当进程数多时，重新计算 counter 需要遍历所有进程
- 实时性不强

---

## 4. 时钟中断与调度触发

### 4.1 时钟中断流程

系统每 10ms 产生一次时钟中断（IRQ 0），执行流程：

```
硬件时钟中断 (IRQ 0)
    ↓
timer_interrupt (system_call.s:176)
    ↓
保存寄存器
    ↓
jiffies++  (增加系统滴答计数)
    ↓
do_timer(CPL)  (sched.c:305)
    ↓
根据 CPL 更新进程时间统计 (用户态/内核态)
    ↓
current->counter--  (递减当前进程时间片)
    ↓
if (counter <= 0 && CPL != 0)  (时间片用完且在用户态)
    ↓
schedule()  (调用调度器)
    ↓
ret_from_sys_call  (返回用户空间)
    ↓
恢复寄存器
    ↓
iret (中断返回)
```

### 4.2 timer_interrupt 汇编代码

```asm
# system_call.s:176
timer_interrupt:
    push %ds
    push %es
    push %fs
    pushl %edx
    pushl %ecx
    pushl %ebx
    pushl %eax
    
    movl $0x10,%eax        # 设置内核数据段
    mov %ax,%ds
    mov %ax,%es
    movl $0x17,%eax
    mov %ax,%fs
    
    incl jiffies           # 系统时间 +1
    
    movb $0x20,%al         # 发送 EOI 给中断控制器
    outb %al,$0x20
    
    movl CS(%esp),%eax     # 获取 CPL（特权级）
    andl $3,%eax           # 0=内核态，3=用户态
    pushl %eax
    call do_timer          # 调用 C 函数
    addl $4,%esp
    
    jmp ret_from_sys_call  # 返回
```

### 4.3 do_timer 函数

```c
// sched.c:305
void do_timer(long cpl)
{
    // 更新时间统计
    if (cpl)
        current->utime++;   // 用户态时间
    else
        current->stime++;   // 内核态时间
    
    // 处理定时器
    if (next_timer) {
        next_timer->jiffies--;
        while (next_timer && next_timer->jiffies <= 0) {
            void (*fn)(void);
            fn = next_timer->fn;
            next_timer->fn = NULL;
            next_timer = next_timer->next;
            (fn)();
        }
    }
    
    // 处理软驱定时器
    if (current_DOR & 0xf0)
        do_floppy_timer();
    
    // 时间片递减
    if ((--current->counter) > 0) 
        return;              // 还有时间片，直接返回
    
    current->counter = 0;
    
    if (!cpl) 
        return;              // 在内核态，不调度
    
    schedule();              // 用户态且时间片用完，进行调度
}
```

**关键点：**
1. 时间片用完（counter=0）
2. 当前在用户态（cpl != 0）
3. 满足这两个条件才会调用 `schedule()`

---

## 5. schedule() 函数详解

`schedule()` 是调度器的核心，负责选择下一个要运行的进程。

### 5.1 完整代码分析

```c
// sched.c:104
void schedule(void)
{
    int i, next, c;
    struct task_struct **p;

    /* 第一阶段：处理信号和闹钟 */
    // 从后向前遍历任务数组
    for(p = &LAST_TASK; p > &FIRST_TASK; --p) {
        if (*p) {
            // 检查闹钟是否到期
            if ((*p)->alarm && (*p)->alarm < jiffies) {
                (*p)->signal |= (1 << (SIGALRM-1));  // 发送 SIGALRM 信号
                (*p)->alarm = 0;
            }
            
            // 如果进程有未阻塞的信号且处于可中断睡眠状态，唤醒它
            if (((*p)->signal & ~(_BLOCKABLE & (*p)->blocked)) &&
                (*p)->state == TASK_INTERRUPTIBLE)
                (*p)->state = TASK_RUNNING;
        }
    }

    /* 第二阶段：选择下一个进程 */
    while (1) {
        c = -1;              // c 用于记录最大的 counter 值
        next = 0;            // next 是下一个要运行的进程索引
        i = NR_TASKS;
        p = &task[NR_TASKS];
        
        // 从后向前遍历，找出 counter 最大的 RUNNING 进程
        while (--i) {
            if (!*--p)
                continue;    // 跳过空任务槽
            
            if ((*p)->state == TASK_RUNNING && (*p)->counter > c)
                c = (*p)->counter, next = i;
        }
        
        // 如果找到了 counter > 0 的进程，退出循环
        if (c) 
            break;
        
        // 所有进程的 counter 都是 0，重新计算 counter
        for(p = &LAST_TASK; p > &FIRST_TASK; --p) {
            if (*p)
                (*p)->counter = ((*p)->counter >> 1) + (*p)->priority;
        }
    }
    
    /* 第三阶段：切换到选中的进程 */
    switch_to(next);
}
```

### 5.2 执行流程图

```
                    schedule() 开始
                         |
                         v
        +--------------------------------+
        |   遍历所有进程                  |
        |   - 检查 alarm                 |
        |   - 处理信号                   |
        |   - 唤醒可中断睡眠的进程         |
        +--------------------------------+
                         |
                         v
        +--------------------------------+
        |   查找 counter 最大的进程       |
        |   (只考虑 TASK_RUNNING 状态)   |
        +--------------------------------+
                         |
                         v
                   找到了吗？(c > 0)
                   /            \
                 是              否
                 |               |
                 v               v
        +---------------+   +------------------+
        | switch_to(n)  |   | 重新计算 counter  |
        +---------------+   | counter = (c>>1) |
                           |      + priority   |
                           +------------------+
                                    |
                                    v
                           +------------------+
                           | 重新查找进程      |
                           +------------------+
                                    |
                                    v
                           +------------------+
                           | switch_to(n)     |
                           +------------------+
```

### 5.3 关键点解释

#### 5.3.1 为什么要重新计算 counter？

当所有可运行进程的 counter 都为 0 时，意味着：
- 所有进程都用完了时间片
- 需要重新分配时间片

公式 `counter = (counter >> 1) + priority` 的巧妙之处：
- 右移一位相当于除以 2
- 如果进程主动放弃了 CPU（如等待 I/O），它的 counter 不会减到 0
- 重新计算时，这些进程会保留一半的剩余时间片，再加上 priority
- **这样 I/O 密集型进程会得到更高的优先级**，提高系统响应性

**示例：**
```
进程 A (priority=15, counter=0)   // CPU 密集型，用完了时间片
进程 B (priority=15, counter=8)   // I/O 密集型，主动睡眠过

重新计算：
A: counter = (0 >> 1) + 15 = 15
B: counter = (8 >> 1) + 15 = 19

结果：B 会先运行，因为它的 counter 更大
```

#### 5.3.2 为什么 Task 0 特殊？

- Task 0 是 idle 进程
- 它的 counter 永远是 0
- 只有当没有其他可运行进程时，才会选中它
- 这样保证了 CPU 永远有事可做

---

## 6. 任务切换 switch_to

### 6.1 switch_to 宏定义

```c
// include/linux/sched.h:173
#define switch_to(n) { \
    struct {long a,b;} __tmp; \
    __asm__("cmpl %%ecx,current\n\t"      /* 比较 current 和 task[n] */ \
            "je 1f\n\t"                   /* 如果相同，跳转到 1，不切换 */ \
            "movw %%dx,%1\n\t"            /* 保存新 TSS 的选择符 */ \
            "xchgl %%ecx,current\n\t"     /* 交换 ecx 和 current */ \
            "ljmp *%0\n\t"                /* 长跳转，触发任务切换！ */ \
            "cmpl %%ecx,last_task_used_math\n\t" \
            "jne 1f\n\t" \
            "clts\n"                      /* 清除 TS 标志 */ \
            "1:" \
            ::"m" (*&__tmp.a),"m" (*&__tmp.b), \
            "d" (_TSS(n)),"c" ((long) task[n])); \
}
```

### 6.2 任务切换详解

**关键指令：`ljmp *%0`（长跳转）**

这条指令是任务切换的核心：
1. 它跳转到新的 TSS 段选择符
2. CPU 硬件自动完成以下操作：
   - 保存当前进程的所有寄存器到当前 TSS
   - 从新 TSS 加载所有寄存器
   - 切换 LDT（局部描述符表）
   - 切换页目录（CR3）

**这就是 Intel CPU 的硬件任务切换机制！**

### 6.3 任务切换的完整流程

```
                    switch_to(next)
                         |
                         v
              +------------------------+
              | 比较 task[next] 和     |
              | current 是否相同        |
              +------------------------+
                         |
                    相同吗？
                   /        \
                 是          否
                 |           |
                 v           v
            直接返回    +-------------------+
                       | 保存新 TSS 选择符  |
                       +-------------------+
                                |
                                v
                       +-------------------+
                       | current = task[n] |
                       +-------------------+
                                |
                                v
                       +-------------------+
                       | ljmp *tss_selector|
                       +-------------------+
                                |
                                v
           +------------------------------------------+
           |     CPU 硬件自动执行：                    |
           |  1. 保存当前寄存器到当前 TSS              |
           |     - eax, ebx, ecx, edx, esi, edi      |
           |     - esp, ebp, eip, eflags             |
           |     - cs, ds, es, fs, gs, ss            |
           |  2. 从新 TSS 加载所有寄存器              |
           |  3. 切换到新进程的 LDT                   |
           |  4. 切换页目录 (CR3)                     |
           +------------------------------------------+
                                |
                                v
                    新进程开始/继续执行！
```

### 6.4 TSS 在 GDT 中的布局

```
GDT (全局描述符表):
+--------+
| NULL   | 0
+--------+
| CS     | 0x08
+--------+
| DS     | 0x10
+--------+
| SYSCALL| 0x18
+--------+
| TSS0   | 0x20  (FIRST_TSS_ENTRY=4)
+--------+
| LDT0   | 0x28  (FIRST_LDT_ENTRY=5)
+--------+
| TSS1   | 0x30
+--------+
| LDT1   | 0x38
+--------+
| ...    |
+--------+

_TSS(n) = (n << 4) + (FIRST_TSS_ENTRY << 3)
        = n * 16 + 32

例如：
_TSS(0) = 0x20
_TSS(1) = 0x30
_TSS(2) = 0x40
```

### 6.5 为什么用硬件任务切换？

**优点：**
- 硬件自动保存/恢复所有寄存器，可靠
- 代码简单，不容易出错

**缺点：**
- 较慢（保存的东西太多）
- 后来的 Linux（2.0+）改用软件任务切换，只保存必要的寄存器

---

## 7. 睡眠与唤醒机制

### 7.1 sleep_on - 不可中断睡眠

```c
// sched.c:151
void sleep_on(struct task_struct **p)
{
    struct task_struct *tmp;

    if (!p)
        return;
    if (current == &(init_task.task))
        panic("task[0] trying to sleep");  // task 0 不能睡眠
    
    tmp = *p;          // 保存旧的等待进程
    *p = current;      // 当前进程进入等待队列
    current->state = TASK_UNINTERRUPTIBLE;  // 设置为不可中断睡眠
    schedule();        // 主动放弃 CPU
    
    // 当被唤醒后，代码从这里继续
    if (tmp)
        tmp->state = 0;  // 唤醒前一个等待进程（形成链式唤醒）
}
```

**等待队列结构：**

```
等待队列是一个单向链表，通过临时变量 tmp 连接：

初始： *p = NULL

进程 A sleep_on(p):
    tmp_A = NULL
    *p = A
    A->state = UNINTERRUPTIBLE

进程 B sleep_on(p):
    tmp_B = A           // 保存了前一个等待者
    *p = B              // B 成为队首
    B->state = UNINTERRUPTIBLE

进程 C sleep_on(p):
    tmp_C = B
    *p = C
    C->state = UNINTERRUPTIBLE

等待队列： C -> B -> A

wake_up(p):
    *p = NULL
    C->state = RUNNING  // C 被唤醒
    
C 被调度运行后，从 schedule() 返回，执行：
    if (tmp_C)  // tmp_C = B
        tmp_C->state = 0;  // 唤醒 B
    
B 被调度后：
    if (tmp_B)  // tmp_B = A
        tmp_B->state = 0;  // 唤醒 A
    
形成链式唤醒！
```

### 7.2 interruptible_sleep_on - 可中断睡眠

```c
// sched.c:167
void interruptible_sleep_on(struct task_struct **p)
{
    struct task_struct *tmp;

    if (!p)
        return;
    if (current == &(init_task.task))
        panic("task[0] trying to sleep");
    
    tmp = *p;
    *p = current;
repeat:
    current->state = TASK_INTERRUPTIBLE;  // 可中断睡眠
    schedule();
    
    // 被唤醒后检查
    if (*p && *p != current) {
        (**p).state = 0;   // 唤醒新的队首
        goto repeat;       // 再次睡眠
    }
    
    *p = NULL;
    if (tmp)
        tmp->state = 0;
}
```

**与 sleep_on 的区别：**
- 状态是 `TASK_INTERRUPTIBLE`
- 可以被信号唤醒（在 schedule() 中检查）
- 有更复杂的唤醒逻辑

### 7.3 wake_up - 唤醒进程

```c
// sched.c:188
void wake_up(struct task_struct **p)
{
    if (p && *p) {
        (**p).state = 0;      // 设置为 TASK_RUNNING
        *p = NULL;            // 清空等待队列指针
    }
}
```

### 7.4 使用示例

**等待磁盘操作：**

```c
// 等待磁盘就绪
struct task_struct *wait_for_hd = NULL;

// 在中断处理程序中
void hd_interrupt_handler(void)
{
    // 磁盘操作完成
    wake_up(&wait_for_hd);  // 唤醒等待的进程
}

// 在读磁盘函数中
void read_hd(void)
{
    // 启动磁盘操作
    outb_p(cmd, HD_CMD);
    
    // 等待完成
    sleep_on(&wait_for_hd);
    
    // 被唤醒后继续
    // 读取数据...
}
```

---

## 8. 完整执行流程示例

### 8.1 从时钟中断到进程切换

假设系统中有 3 个进程：

```
Task 0: idle (counter=0, priority=0)      - 空闲进程
Task 1: shell (counter=3, priority=15)    - 当前运行
Task 2: editor (counter=10, priority=15)  - 就绪
```

**执行流程：**

```
时刻 T0: shell 正在运行 (current = Task 1)
    |
    | (时钟中断)
    v
[1] timer_interrupt 
    - 保存 shell 的寄存器到栈
    - jiffies++
    - 调用 do_timer(3)  // CPL=3 表示用户态

[2] do_timer(3)
    - current->utime++              // shell 用户态时间 +1
    - current->counter--            // shell: 3 -> 2
    - if (counter > 0) return;      // 2 > 0, 返回
    
[3] 返回 ret_from_sys_call
    - 检查信号
    - iret 返回用户态
    - shell 继续运行

==========================================

时刻 T1: shell 继续运行
    | (再过 2 次时钟中断)
    v
[1] do_timer(3)
    - current->counter--    // shell: 2 -> 1 -> 0
    - if (counter > 0) return;  // 0 不满足
    - current->counter = 0;
    - if (!cpl) return;     // cpl=3，不返回
    - schedule();           // 调用调度！

[2] schedule()
    阶段 1: 检查信号
    - 没有特殊情况
    
    阶段 2: 选择进程
    - 遍历进程：
      Task 0: counter=0, state=RUNNING  -> 不选
      Task 1: counter=0, state=RUNNING  -> 不选  
      Task 2: counter=10, state=RUNNING -> 选中！c=10, next=2
    - c=10 > 0, break
    
    阶段 3: 切换
    - switch_to(2)

[3] switch_to(2)
    - current != task[2], 需要切换
    - movw %dx,%1           // 保存 TSS 选择符
    - xchgl %ecx,current    // current = Task 2
    - ljmp *%0              // 长跳转到 Task 2 的 TSS

[4] CPU 硬件操作
    - 保存 shell 的所有寄存器到 Task 1 的 TSS
      (eip, esp, eflags, eax, ebx, ...)
    - 从 Task 2 的 TSS 加载所有寄存器
    - 切换到 Task 2 的 LDT
    - 切换页目录 (cr3 = Task 2 的页目录)
    
[5] editor 开始运行！
    - 从 editor 上次停止的地方继续
    - (可能也是从 schedule() 返回)

==========================================

时刻 T2: editor 继续运行
    | (经过 10 次时钟中断)
    v
[1] do_timer(3)
    - editor->counter--     // 10 -> 9 -> ... -> 0
    - schedule();

[2] schedule()
    - 遍历进程：
      Task 0: counter=0  -> 不选
      Task 1: counter=0  -> 不选
      Task 2: counter=0  -> 不选
    - c = -1，没有找到
    
    - 重新计算 counter：
      Task 0: (0>>1) + 0 = 0
      Task 1: (0>>1) + 15 = 15
      Task 2: (0>>1) + 15 = 15
    
    - 再次遍历：
      Task 0: counter=0  -> 不选
      Task 1: counter=15 -> 选中！c=15, next=1
      Task 2: counter=15 -> 不选（已经选了 Task 1）
    
    - switch_to(1)

[3] switch_to(1) 
    - CPU 硬件切换
    - 从 Task 2 切换到 Task 1
    
[4] shell 继续运行！
    - counter = 15（刚分配的新时间片）
```

### 8.2 时序图

```
时间 →
------------------------------------------------------------
Task 1 |████████|______|██████████████|______|
(shell)|  运行   | 等待 |      运行      | 等待 |

Task 2 |________|██████████████|______|██████|
(edit) |  等待   |      运行      | 等待 | 运行  |

中断   |   ↓   ↓   ↓   ↓   ↓   ↓   ↓   ↓   ↓   ↓
       | timer interrupt (每 10ms)

调度   |        ↓              ↓
       |     调度到 Task 2   调度到 Task 1
```

### 8.3 从睡眠到唤醒的例子

```
场景：Task 1 等待键盘输入

[1] Task 1 调用 read(stdin)
    -> sys_read()
    -> tty_read()
    -> 没有数据可读

[2] tty_read() 调用 sleep_on(&tty->wait)
    - tmp = tty->wait     // NULL
    - tty->wait = Task 1  // Task 1 进入等待队列
    - Task 1->state = TASK_UNINTERRUPTIBLE
    - schedule()          // 主动放弃 CPU

[3] schedule() 选择其他进程运行
    - Task 2 被选中
    - switch_to(2)
    - Task 1 睡眠，Task 2 运行

[4] 用户按下键盘
    -> 键盘中断
    -> keyboard_interrupt()
    -> 数据放入 tty 缓冲区
    -> wake_up(&tty->wait)

[5] wake_up(&tty->wait)
    - Task 1->state = TASK_RUNNING  // 唤醒 Task 1
    - tty->wait = NULL

[6] 下次调度时
    - schedule() 发现 Task 1 是 RUNNING
    - 根据 counter 可能选中 Task 1
    - switch_to(1)
    - Task 1 从 schedule() 返回
    - 继续执行 sleep_on() 后面的代码
    - 返回 tty_read()
    - 读取缓冲区数据
    - 返回用户空间
```

---

## 9. 系统调用中的调度检查

### 9.1 系统调用返回时的检查

每个系统调用返回用户空间前，都会检查是否需要重新调度：

```asm
# system_call.s:80
system_call:
    # 保存寄存器
    push %ds
    push %es
    push %fs
    pushl %edx
    pushl %ecx
    pushl %ebx
    
    # 调用系统调用函数
    call *sys_call_table(,%eax,4)
    pushl %eax                    # 保存返回值
    
    # 检查是否需要调度
    movl current,%eax
    cmpl $0,state(%eax)           # 检查进程状态
    jne reschedule                # 不是 RUNNING，重新调度
    
    cmpl $0,counter(%eax)         # 检查时间片
    je reschedule                 # 时间片用完，重新调度

ret_from_sys_call:
    # 处理信号
    # 恢复寄存器
    # iret 返回

reschedule:
    pushl $ret_from_sys_call      # 返回地址
    jmp schedule                  # 跳转到调度函数
```

**为什么要检查？**

进程可能在系统调用中：
- 主动睡眠（如 wait(), read()）
- 时间片用完
- 被信号中断

需要在返回用户空间前重新调度。

### 9.2 pause() 系统调用

最简单的主动放弃 CPU 的方法：

```c
// sched.c:144
int sys_pause(void)
{
    current->state = TASK_INTERRUPTIBLE;  // 进入可中断睡眠
    schedule();                           // 主动调度
    return 0;
}
```

---

## 10. 调度相关的其他系统调用

### 10.1 nice() - 改变优先级

```c
// sched.c:378
int sys_nice(long increment)
{
    if (current->priority - increment > 0)
        current->priority -= increment;  // 降低优先级（增加 nice 值）
    return 0;
}
```

### 10.2 alarm() - 设置闹钟

```c
// sched.c:338
int sys_alarm(long seconds)
{
    int old = current->alarm;
    
    if (old)
        old = (old - jiffies) / HZ;  // 返回剩余秒数
    
    current->alarm = (seconds > 0) ? (jiffies + HZ * seconds) : 0;
    return old;
}
```

闹钟在 `schedule()` 中检查：

```c
if ((*p)->alarm && (*p)->alarm < jiffies) {
    (*p)->signal |= (1 << (SIGALRM-1));  // 发送 SIGALRM 信号
    (*p)->alarm = 0;
}
```

---

## 11. 调度器初始化

### 11.1 sched_init()

系统启动时调用，初始化调度相关数据结构：

```c
// sched.c:385
void sched_init(void)
{
    int i;
    struct desc_struct *p;

    // 设置 Task 0 的 TSS 和 LDT
    set_tss_desc(gdt + FIRST_TSS_ENTRY, &(init_task.task.tss));
    set_ldt_desc(gdt + FIRST_LDT_ENTRY, &(init_task.task.ldt));
    
    // 清空其他任务槽的 TSS 和 LDT
    p = gdt + 2 + FIRST_TSS_ENTRY;
    for(i = 1; i < NR_TASKS; i++) {
        task[i] = NULL;
        p->a = p->b = 0;  // TSS
        p++;
        p->a = p->b = 0;  // LDT
        p++;
    }
    
    // 清除 NT 标志
    __asm__("pushfl ; andl $0xffffbfff,(%esp) ; popfl");
    
    // 加载 Task 0 的 TSS 和 LDT
    ltr(0);
    lldt(0);
    
    // 设置时钟中断（IRQ 0, INT 0x20）
    outb_p(0x36, 0x43);              // 设置 8253 定时器
    outb_p(LATCH & 0xff, 0x40);      // 低字节
    outb(LATCH >> 8, 0x40);          // 高字节
    set_intr_gate(0x20, &timer_interrupt);  // 设置中断门
    outb(inb_p(0x21) & ~0x01, 0x21); // 打开 IRQ 0
    
    // 设置系统调用（INT 0x80）
    set_system_gate(0x80, &system_call);
}
```

**初始化步骤：**
1. 设置 Task 0（init 进程）的 TSS 和 LDT 到 GDT
2. 清空其他任务槽
3. 加载 Task 0 的 TSS 和 LDT
4. 设置时钟中断（每 10ms）
5. 设置系统调用中断

---

## 12. 总结

### 12.1 调度算法要点

| 特性 | 说明 |
|-----|------|
| **算法类型** | 基于优先级的时间片轮转 |
| **时间片** | 由 priority 决定，初始 15 个时钟滴答 |
| **调度策略** | 选择 counter 最大的 RUNNING 进程 |
| **抢占** | 时钟中断时检查，时间片用完则重新调度 |
| **重新计算** | `counter = (counter >> 1) + priority` |
| **任务切换** | 使用 Intel 硬件任务切换（TSS + ljmp） |

### 12.2 关键函数

| 函数 | 作用 | 调用时机 |
|-----|------|---------|
| `schedule()` | 核心调度函数 | 时间片用完、主动睡眠、系统调用返回 |
| `switch_to(n)` | 切换到进程 n | schedule() 选定进程后 |
| `do_timer()` | 时钟中断处理 | 每 10ms 一次 |
| `sleep_on()` | 不可中断睡眠 | 等待资源（如磁盘） |
| `interruptible_sleep_on()` | 可中断睡眠 | 等待可能被信号中断的资源 |
| `wake_up()` | 唤醒进程 | 资源就绪时 |

### 12.3 进程状态转换图

```
                    fork()
                      |
                      v
                [TASK_RUNNING]  <------------+
                   |       ^                 |
    sleep_on()     |       |  wake_up()      |
    or pause()     |       |                 |
                   v       |                 |
            [TASK_INTERRUPTIBLE] <----+      |
                   |                  |      |
                   | sleep_on()    signal    |
                   v                  |      |
          [TASK_UNINTERRUPTIBLE] -----+      |
                   |                         |
                   | wake_up()               |
                   +-------------------------+
                   
            exit()  
                   |
                   v
             [TASK_ZOMBIE]
                   |
                   | wait() by parent
                   v
                [删除]
```

### 12.4 调度时机总结

1. **时钟中断**（最常见）
   - 每 10ms 触发
   - current->counter 递减
   - 为 0 且在用户态时调用 schedule()

2. **系统调用返回**
   - 检查 state 是否为 RUNNING
   - 检查 counter 是否为 0

3. **主动睡眠**
   - sleep_on()
   - interruptible_sleep_on()
   - sys_pause()

4. **等待资源**
   - 等待 I/O
   - 等待信号
   - 等待子进程

### 12.5 调度的公平性

Linux 0.11 的调度算法保证了：

1. **CPU 密集型进程**：
   - 用完时间片后被调度出去
   - 下次重新计算时得到 priority 大小的时间片

2. **I/O 密集型进程**：
   - 经常主动睡眠，counter 不会减到 0
   - 重新计算时保留一半剩余时间片
   - 得到更多 CPU 时间，提高响应性

3. **所有进程**：
   - 最终都会得到 CPU 时间
   - 不会饿死

### 12.6 Linux 0.11 vs 现代 Linux

| 特性 | Linux 0.11 | 现代 Linux (5.x+) |
|-----|-----------|------------------|
| 调度算法 | 简单优先级 + 时间片 | CFS (完全公平调度器) |
| 时间复杂度 | O(n) | O(log n) |
| 任务切换 | 硬件 TSS | 软件切换 |
| 实时支持 | 无 | 有 (SCHED_FIFO, SCHED_RR) |
| 多核支持 | 无 | 有（复杂的负载均衡） |
| 调度类 | 单一 | 多个（CFS, RT, Deadline） |

---

## 附录

### A. 相关代码文件

- `kernel/sched.c` - 调度核心实现
- `kernel/system_call.s` - 系统调用和中断处理
- `include/linux/sched.h` - 进程控制块定义
- `include/asm/system.h` - 底层系统宏
- `kernel/fork.c` - 进程创建
- `kernel/exit.c` - 进程退出

### B. 重要常量

```c
#define HZ 100                    // 时钟频率 100Hz (10ms)
#define NR_TASKS 64               // 最多 64 个进程
#define LATCH (1193180/HZ)        // 8253 定时器的计数值

#define TASK_RUNNING            0
#define TASK_INTERRUPTIBLE      1
#define TASK_UNINTERRUPTIBLE    2
#define TASK_ZOMBIE             3
#define TASK_STOPPED            4

#define FIRST_TSS_ENTRY 4
#define FIRST_LDT_ENTRY 5
```

### C. 调试技巧

1. **打印进程状态**：
   ```c
   void show_task(int nr, struct task_struct *p) {
       printk("%d: pid=%d, state=%d, counter=%ld, priority=%ld\n",
              nr, p->pid, p->state, p->counter, p->priority);
   }
   ```

2. **追踪调度**：
   在 schedule() 开始加上：
   ```c
   printk("schedule: from task %d\n", current->pid);
   ```

3. **使用 GDB**：
   ```bash
   (gdb) b schedule
   (gdb) c
   (gdb) p *current
   (gdb) p task[1]->counter
   ```

---

**文档版本：** v1.0  
**最后更新：** 2026-01-07  
**作者：** Based on Linux 0.11 source code analysis

