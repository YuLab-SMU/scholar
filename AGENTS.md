# scholar (YuLab-SMU/scholar) — 项目工作笔记

开发基线：CRAN 已发 `1.0.0`（见 `CRAN-SUBMISSION`），开发期版本号按 `1.0.0.NNN` 逐 commit 递增；
`NEWS.md` 顶部小节标题就是当前临时号，新条目写在同一个标题下最前面，已发布小节不动。
issue 号：本仓库直接写 `#N`；上游 `jkeirstead/scholar` 必须写 `jkeirstead#N`（两边号会撞，例如 `#4`）。

## 本机运行环境（不做会误判）

- R 包在 `~/Rlib`：任何 `Rscript` 前先 `export R_LIBS_USER=~/Rlib`。
- **访问 Google Scholar 必须走代理**：`export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897`。
  直连超时是常态，不是 DNS 问题。OpenAlex（`api.openalex.org`）可直连，无需代理。
- `make` 目标即项目流程：`make rd`（roxygenise）→ `make check`（`devtools::check()`）。别绕开它自己拼命令。
- 跑 `make check` 时置 **`NOT_CRAN=false`**：否则 `devtools::check()` 会跑联网测试与 `--run-donttest` 示例，
  在本机这种共享出口 IP 上等于自取 429（一次全量约 3 分钟，主要耗在示例的联网重试上）。

## Google Scholar 的限流现实（2026-10-29 实测）

| 端点 | 匿名可用？ | 备注 |
|---|---|---|
| `citations?user=` / `view_op=list_works` / `list_colleagues` / `view_citation` | 可以（浏览器 UA） | 本包的可靠核心 |
| `view_op=search_authors` | **不行** | 一律 302 → `accounts.google.com/Login`（带浏览器 UA 则去 `google.com/sorry`）。需要登录 session，改 header 无效 → `get_scholar_id()`/`search_scholar_ids()` 已按“匿名路径弃用”处理，改用 `search_openalex_authors()` |
| `scholar?cites=<cid>`（谁引用了这篇） | **机房/共享 IP 不行** | 返回 **HTTP 200 的 JS 验证码壳页**；同 IP 的 `scholar?q=` 却能出结果。`get_citing_articles()` 的解析用真实页面验证过，端到端取数需住宅 IP 或 `set_scholar_cookie()` |
| `scimagojr.com/journalrank.php` | **完全不行** | 2025 年底起 Cloudflare JS 挑战，`?out=xls`/`?export=csv` 都 403；数据无公开许可 → `get_journalrank()` 已弃用，不再下载任何数据（期刊指标走 OpenAlex `/sources`） |

- 这个出口 IP **很快就被 429**（连续十几次请求即触发，冷却十几分钟量级）。
  **调试优先用 fixture / mock，不要把 live 请求当循环反馈**；要联网验证就一次多测几件事、请求间 `sleep 3-8`。
- 判据坑：判"壳页/被拒"必须用**属性形态**字符串（`class="gs_ri"`、`id="gs_res_ccl_mid"`、
  `class="gsc_a_tr"`、`id="gsc_prf_in"`）。裸类名一定误判——每张 Scholar 页面都内联了定义这些类名的 CSS。
- `Retry-After` 两种形态都要解：秒数、以及 HTTP 日期（`Wed, 21 Oct 2026 07:28:00 GMT`）。超过预算就该放弃而不是硬等。

## R / httr 的硬坑（都已写成回归测试）

1. **`httr::GET(url, list_of_configs)` 会被静默丢弃**，请求照旧用 `libcurl/x` 的 UA 发出去。
   必须逐个作为独立参数传：`do.call(httr::GET, c(list(url=url, config=list(), handle=handle), settings))`
   ——`config=list()` 要显式绑上，否则第一个对象按位置落进 `config` 槽。锁死在 `test-scholar-response.R`。
2. **发 cookie 用 `httr::set_cookies(!!!pairs)`（CURLOPT_COOKIE），不要用 `add_headers(Cookie=…)`**。
   后者与 curl 的 cookie 引擎冲突（实测同给时配置值被挤掉），且跨主机重定向时被 libcurl 剥掉——
   正好是登录跳转那一跳。`set_cookies` 会与引擎合并成一个头（`SERVER=1; NID=abc`）。
   另：`set_cookies("NID=a; SOCS=b")` 会被编码成 `=NID%3Da%3B…`，**必须拆成具名参数**。
   session 只发给 Google 域名（`set_scholar_mirror()` 指向第三方镜像时拒绝发送并说明原因）。
3. **本包没开 roxygen markdown**：`[fn()]`、`[a][b]` 会原样出现在 Rd 里。写 Rd 原语
   （`\code{\link{fn}}`、`\url{}`）。⚠ 用脚本批量转换时小心**双重转义**——`\\code{\\link{}}` 会让
   `R CMD check` 报 `Lost braces`，而这只有全量 check 能看见。
4. **示例（`\donttest`）是 check 的高发事故区**，单元测试永远不跑它们：
   取数失败时 `get_publications()` 返回 `NA`，示例里必须 `is.data.frame()` 守卫（历史上 `get_scholar_id` 的 `aa` 与
   `get_citing_articles` 的 `pubs$pubid[1]` 都是同一类崩溃）；ggplot2 在 Imports 不 attach，示例里必须 `ggplot2::` 前缀或别画；
   示例不要做 N 次请求（`get_h_index_history` 只取前 3 篇）。
5. 联网测试的跳过条件必须针对"**该网站不可用**"而不是"没有网络"：用
   `tests/testthat/test-scholar.R` 里的 `skip_if_no_scholar_data()` / `skip_if_no_publications()`；
   `skip_if_offline()` 挡不住 Scholar 单独封 IP，runner 是在线的。
6. `make rd` 会把 `NAMESPACE` 重排成多行 `importFrom(...)` 并抬 `Config/roxygen2/version`——
   这是 roxygen 8.1.1 的正常噪声，别当成别人的改动。

## 测试资产

- `tests/testthat/fixtures/citing-page.html`：**真实** Scholar 结果页的裁剪样本（两行结果）。
  写解析器请以它为准，不要照记忆造 DOM。要更新就用代理抓一页 `scholar?q=` 结果，取
  `#gs_res_ccl_mid` 的头两行原样存下来。
- 新增文件（`R/*.R`）后必须 `make rd`，否则 `R CMD check` 报缺文档；导出函数一律有 Rd。
