# CCPCOJ / CSGOJ 组织 XCPC 比赛操作手册

用 CCPCOJ / CSGOJ 办一场 XCPC 标准赛：建比赛、导题、生成账号、抽签、打印、气球、直播、获奖导出、滚榜。

原文：<https://github.com/CSGrandeur/CCPCOJ/blob/master/doc/user_doc.md>

## 目录

- [1. 总体流程](#1-总体流程)
- [2. 登录与角色](#2-登录与角色)
- [3. 赛前配置](#3-赛前配置)
- [4. 赛中运行](#4-赛中运行)
- [5. 赛后与闭幕](#5-赛后与闭幕)
- [6. 检查清单](#6-检查清单)

## 1. 总体流程

按赛前、赛中、赛后做即可。

| 阶段 | 要做的事 | 结果 |
| --- | --- | --- |
| 赛前 | 建比赛、导题、生成队伍和工作人员账号、抽签、打印密码条 | 比赛可登录，账号表、座位表、题目和评测都就绪 |
| 赛中 | 打印、气球、榜单、直播叠加 | 现场服务能跑起来 |
| 赛后 | 导出获奖、滚榜、照片和离线包 | 获奖名单、滚榜、闭幕式材料 |

正式赛前至少完整走一遍：

- 题目导入和评测
- 队伍账号生成、导入、登录
- 机位抽签和结果导出
- 打印员、气球员、直播账号登录
- 大屏榜单和 RankRoll 滚榜

## 2. 登录与角色

### 2.1 登录入口

- 管理员：左侧菜单栏任意空白处快速三击，弹出管理员登录框。
- 比赛内账号：进入比赛主页后，在公告区域登录。

![alt text](<user_doc_image/Frame 1.png>)

### 2.2 角色

| 角色 | 用途 | 何时用 |
| --- | --- | --- |
| 系统管理员 | 建比赛、导题、生成账号、导出数据 | 赛前、赛后 |
| 队伍账号 | 参赛队伍登录 | 热身赛、正式赛 |
| 打印员 printer | 处理选手打印请求 | 赛中 |
| 气球管理员 balloon_manager | 看气球任务，必要时分配或撤销 | 赛中 |
| 气球配送员 balloon_sender | 领取并完成气球配送 | 赛中 |
| 直播 watcher | 进直播控制台，生成 OBS 叠加层链接 | 赛中 |
| 比赛 admin / 监考员 | 现场监管、闭幕式滚榜 | 赛中、闭幕式 |

## 3. 赛前配置

### 3.1 创建比赛

后台添加比赛时，类型选 **Standard**。

![alt text](<user_doc_image/Frame 2.png>)

#### 获奖比例

获奖比例可以写成：

1. 百分比
2. 固定数量

### 3.2 添加题目

题面用 Markdown，公式用 LaTeX。后台经 Pandoc 编译。

1. 先创建题目。
2. 进入题目编辑页。
3. 上传图片附件。
4. 从上传列表复制相对路径插入题面，不用再拼 URL。

![alt text](<user_doc_image/Frame 3.png>)

![alt text](<user_doc_image/Frame 4.png>)

#### LaTeX 题面

某一段需要按 LaTeX 解析时，在该段开头单独写一行：

```text
__LATEX__
```

之后可用基础 LaTeX，例如 `\textbf{}`、`\includegraphics{}`。具体命令以当前部署版本为准。

### 3.3 Polygon 题目转换器

可以把 [Polygon](https://polygon.codeforces.com/) 导出的题目包转成 CSGOJ 导入格式。

1. 打开 **Parse Polygon Zip**。
2. 上传 Polygon 的 zip。
3. 点 **Help** 看系统要求的目录结构。
4. 解析完成后勾选要导出的题。
5. 点 **Pack Selected To CSGOJ**，生成可导入的题目包。

![alt text](<user_doc_image/Frame 11.png>)

#### Special Judge 开关

Polygon 一般会给每道题生成 `check.cpp`。导出时按题目是否需要 Special Judge 改对应列：

- 开：导出带 `tpj.cc` 的 Special Judge 包
- 关：按普通题导出

文件规则见下一节。

### 3.4 Special Judge

自定义判题时，把 Special Judge 代码和评测数据一起上传，并在题目设置里勾选 **Special Judge**。

优先用 testlib。

#### 方式一：testlib（推荐）

上传文件名必须是 `tpj.cc`，评测机会自动编译。

- 文件名只能是 `tpj.cc`
- 结果只有 AC / WA，非 AC 一律当 WA
- 用了 `tpj.cc` 就不要再传 `spj.cc`

浮点误差示例：

```cpp
#include "testlib.h"
#include <cmath>

const double eps = 1e-6;

int main(int argc, char* argv[]) {
    registerTestlibCmd(argc, argv);

    while (!ans.seekEof()) {
        double expected = ans.readDouble();
        double actual = ouf.readDouble();

        if (std::fabs(expected - actual) > eps) {
            quitf(_wa, "expected %.6f but found %.6f", expected, actual);
        }
    }

    quitf(_ok, "accepted");
}
```

#### 方式二：OJ 原生 SPJ

上传文件名必须是 `spj.cc`。

- 文件名只能是 `spj.cc`
- 结果只有 AC / WA，非 AC 一律当 WA
- 已经用了 `tpj.cc` 就不要再传 `spj.cc`

浮点误差示例：

```cpp
#include <cstdio>
#include <cmath>

#define AC 0
#define WA 1

const double eps = 1e-6;
char extra[100000];

int main(int argc, char** argv) {
    FILE* input = fopen(argv[1], "r");   // 标准输入
    FILE* answer = fopen(argv[2], "r");  // 标准答案
    FILE* user = fopen(argv[3], "r");    // 用户输出

    double expected, actual;
    while (fscanf(answer, "%lf", &expected) != EOF) {
        if (fscanf(user, "%lf", &actual) != 1) return WA;
        if (std::fabs(expected - actual) > eps) return WA;
    }

    if (fscanf(user, "%s", extra) == 1) return WA;

    fclose(input);
    fclose(answer);
    fclose(user);
    return AC;
}
```

### 3.5 生成队伍账号

两种做法：直接导入队伍信息，或抽签后再导入。

#### 方式一：直接导入

队伍信息已经定好、不需要现场抽签时用这个。

入口：

```text
/cpcsys/admin/contest_teamgen?cid=xxxx
```

`xxxx` 换成比赛 ID。进页面后点 **Help** 看导入格式。先按模板把 Excel 整理好再导入。

![alt text](<user_doc_image/Frame 5.png>)

#### 方式二：抽签后再导入

开幕式或赛前要抽机位时用这个。

先生成一批只有 team 编号和密码的空账号。两个参数：

| 参数 | 填什么 |
| --- | --- |
| 参数 1 | 队伍数量再加大约 50，留冗余 |
| 参数 2 | 密码种子数字 |

### 3.6 机位抽签

地址：

```text
http://[OJ地址]/ojtool/seatdraw
```

只要抽签结果、不导入比赛的话，可以不登录直接用。

#### 承办方抽签、管理员导入

1. 承办方按页面格式准备房间和队伍信息表。
2. 管理员留一份完全一样的表。
3. 承办方在开幕式抽签。热身赛前先模拟一次。
4. 抽完后，承办方把页面上的随机种子发给管理员。
5. 管理员用同一份表、同一个种子，在管理端复现结果。
6. 管理员把抽签结果导入比赛。
7. 承办方按单位序导出结果发给队伍，方便找座位。

![alt text](<user_doc_image/Frame 6.png>)

### 3.7 密码条

队伍账号生成后，在队伍生成页表格右上角点 **XLSX**，下载打印表。

文件里一般有：

- 可裁剪分发的密码条
- 不同排版的打印子表
- 可发布或归档的账号表

打印后按单位、队伍或座位号排好，封装后赛前交给现场。管理员自己留一份备查，现场丢了能补。

### 3.8 生成工作人员账号

入口：

```text
/cpcsys/admin/contest_staffgen?cid=xxxx
```

`xxxx` 换成比赛 ID。

准备打印员、气球员名单，以及学号、姓名、职责等字段。

1. 承办方先整理工作人员 Excel。
2. 管理员在 StaffGen 生成账号。
3. 再额外做两个裁判/监考员 admin：一个现场用，一个赛后滚榜用。
4. 管理员赛前把账号交给承办方。
5. 承办方发给对应志愿者。

![alt text](<user_doc_image/Frame 7.png>)

页面上有 **Gen Template**，可先出模板再拷到 Excel 里改。`balloon_sender` 给每位配送员单独一个账号，方便对任务。

## 4. 赛中运行

### 4.1 打印员 printer

用一台连着打印机的 Windows 电脑，把目标打印机设成系统默认，打印员在这台电脑打开对应比赛，用 printer 账号登录。

多台打印机时，每台对应：

- 一台电脑
- 一个 printer 账号
- 明确的打印区域或任务分工

![alt text](<user_doc_image/Frame 8.png>)

比赛刚开始先用手动能印通。流程稳了再开自动。打印员把页面上的提示看完：浏览器、默认打印机、权限都要对。

### 4.2 气球管理员 balloon_manager

看全局发送情况，必要时手动分配或撤销任务。

在气球管理界面按 **A** 切换模式。

#### 模式一：分配模式 Task Assign Mode

用来观察和核对。配送员领取、标记任务都能在这里看到。

需要时点某个气球任务，在弹窗里分给指定 `balloon_sender`。

![alt text](<user_doc_image/气球队列.png>)

#### 模式二：标记模式 Task Finish Mode

适合线下纸条、线上文档队列这类集中派发。点任务即可标成已下达。

这个模式可以不依赖 `balloon_sender` 账号。

### 4.3 气球配送员 balloon_sender

手机连赛场 Wi-Fi，用系统浏览器打开 OJ，登录自己的 `balloon_sender` 账号。

用手机自带浏览器，不要用微信、QQ 内置浏览器。在页面里拉自己负责区域的任务，送到后双击任务标已发放。要退还任务，双击未发气球的时间列。

### 4.4 大屏展示

可以用外榜，也可以用内网 Dynamic Rank。Dynamic Rank 一般在 Ranklist 页点蓝色 **Dynamic Rank** 进入。

| 操作 | 快捷键 |
| --- | --- |
| 自动刷新 | `A` |
| 自动滚屏 | `B` |
| 浏览器全屏 | `F11` |

正式赛前确认：缩放合适，队名和题目列能完整显示，自动刷新和滚屏正常，内外网访问符合现场网络。

### 4.5 直播

先在 StaffGen 生成 `watcher` 账号。登录后从菜单进 **直播 Live**。

1. 用 `watcher` 登录比赛。
2. 点菜单里的 **直播 Live**。
3. 在控制台里配展示参数和菜单开关。
4. 点 **Open Overlay**，拿到直播 token 链接。
5. OBS Studio 里加「浏览器」源。
6. 把 token 链接填进去，叠到直播画面上。

## 5. 赛后与闭幕

### 5.1 获奖信息

管理员在后台下载获奖表。导出前确认：

- 比赛已经结束
- Status 里没有未判完的提交
- 获奖页面已刷新到最新

承办方用这张表做证书、奖牌、新闻稿和归档。

![alt text](<user_doc_image/Frame 9.png>)

### 5.2 滚榜颁奖 RankRoll

闭幕式滚榜一般由承办方用比赛内监考员 admin 账号操作。管理员可以提前准备一个比赛内 admin 交给承办方。

1. 闭幕式电脑打开对应比赛。
2. 用比赛内 admin 登录。
3. 点 **RankRoll** 进滚榜页。
4. 全屏，按现场流程开始滚榜。

![alt text](<user_doc_image/Frame 12.png>)

#### 队伍照片

滚榜页右上角一般有 **队伍照片**。

| 方式 | 做法 |
| --- | --- |
| 单个上传 | 在对应队伍行直接上传 |
| 批量上传 | 准备各队 `.jpg`，文件名用比赛账号，例如 `team001.jpg`，全选后批量上传 |

照片宽高比用 3:2。差一点系统会裁，差太多不要传。滚榜电脑到服务器网络不稳时，提前完整滚一遍，让浏览器把照片缓存下来。

#### 滚榜缩放

全屏后可用：

- `Ctrl` + 鼠标滚轮
- `Ctrl` + `+` / `-`

屏幕上大约同时显示 12 支队伍，数字要完整，不要出现省略号。

### 5.3 离线滚榜

闭幕式现场访问不了服务器时，用滚榜页右上角 **打包下载**，把数据拷到离线环境再用。

## 6. 检查清单

### 6.1 赛前

- [ ] 比赛类型是 **Standard**
- [ ] 比赛时间、封榜时间、榜单设置已确认
- [ ] 获奖比例或固定名额已确认
- [ ] 题面、样例、附件图片能正常显示
- [ ] 评测数据已上传，普通题和 Special Judge 都测过
- [ ] 队伍账号已生成、导入，抽查能登录
- [ ] 机位抽签演练过，同一随机种子能复现
- [ ] 密码条已打印、封装并交接
- [ ] 打印员、气球员、直播 watcher、比赛 admin 账号已生成
- [ ] 大屏、打印机、OBS、现场网络测过

### 6.2 赛中

- [ ] 打印管理页能收到任务
- [ ] 纸张、墨粉、默认打印机正常
- [ ] 气球任务能生成、领取、完成或退还
- [ ] Ranklist 或 Dynamic Rank 能刷新
- [ ] OBS 里直播叠加层显示正常
- [ ] 盯着评测队列，没有异常堆积

### 6.3 赛后

- [ ] 比赛已结束
- [ ] Status 没有未判完的提交
- [ ] 获奖页已刷新并导出最新表
- [ ] 滚榜账号能登录，RankRoll 能打开
- [ ] 队伍照片已上传，并做过缓存预加载
- [ ] 需要离线滚榜的，已打包下载并在目标电脑试过

### 6.4 容易踩的坑

- Special Judge 文件名必须对：testlib 用 `tpj.cc`，原生 SPJ 用 `spj.cc`
- 用了 `tpj.cc` 就不要再传 `spj.cc`
- 现场抽签：承办方和管理员必须用同一份表、同一个随机种子
- 密码条打印后管理员留一份备查
- 气球配送员用系统自带浏览器，别用微信/QQ 内置浏览器
- 闭幕式滚榜前完整预演一次：照片、缩放、大屏
