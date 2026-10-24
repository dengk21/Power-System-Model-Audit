# 局部fixture验证缓存

缓存只保存知识card小型fixture的结果，不缓存原项目数值通过结论、求解结果、适用判断、来源新鲜度或完整覆盖。仅对已审阅、确定性的card检查器使用；代码环境有未声明外部依赖时不要使用缓存。

项目规划默认在单次调用内复用同一卡片的fixture结果，避免多个组件重复运行。跨进程缓存须显式提供项目内adapter外的目录：

```bash
python /path/to/skill/scripts/psaudit_knowledge.py verify --pattern storage-energy \
  --context energy_state=T+1 --context self_discharge=none \
  --source resilience=/path/to/source \
  --cache-dir /path/to/project/PowerSystemModelAudit/cache/fixtures
```

plan/scaffold及项目freeze/status也可使用相同`--cache-dir`。未指定时不写持久缓存；status默认不创建缓存目录。缓存放在Skill和adapter源目录之外，不列入模型源、证据或绑定；可删除后重建，不影响原始证据。

缓存键包含record、card、cases、checker、项目契约、声明共享依赖、知识执行器、缓存工具的实际字节，以及Python版本/实现和系统平台。命中前仍校验当前知识包及声明哈希；修改卡片、fixture、检查器、共享工具或执行器后旧条目不能沿用。来源文件和本次上下文每次重新核对，局部fixture命中不能授予旧项目的新鲜度或参考资格。别名discovery变化不改变数学缓存。

输出tests_state=CACHED或EXECUTED；executed_fixture_cases与cached_fixture_cases分开统计。缺条件或不适用仍为SKIPPED_SCOPE_OR_REUSE，不能当通过。缓存保留真实失败，损坏/格式不符/结果摘要不一致时重新执行。缓存是本机可重建的优化，不是执行证明或对恶意篡改的认证。

知识verify使用`--refresh-cache`强制执行并替换条目。显式validate/update始终重新执行，不读缓存结果。缓存不改变计划的业务内容，不能把缓存状态写成项目适配器失效条件，也不替代项目测试。
