# 项目审阅

PSAUDIT_UNPREPARED：完成以下实质审阅后移除此标记。

## 独立依据与假设

写参考依据、适用假设和未决争议。逐关系公式、单位、物理索引及源码位置只在 relations.json 维护，可给关系增加 formula、unit 字段；这里引用关系ID，不复制清单。

## 输入映射与解释

记录实际变量/参数读取、单位换算、节点与设备ID、方向和时间边界。使用card时，规范输入映射只在assessment的check_bindings维护，这里仅补充解释或引用，不再抄写。

## 待确认

记录仍需人工判断的条件、独立性和覆盖边界。reviewer与scope只在relations.json填写；运行事实由collect产生，不手写耗时、哈希和通过统计。
