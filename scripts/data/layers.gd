class_name Layers
## 物理层位掩码，和 docs/level-data-format.md 第 4 节一致。

const WORLD := 1 << 0
const CRACKED := 1 << 1
const MIRROR := 1 << 2
const PAD := 1 << 3
const VINE := 1 << 4
const PLAYER := 1 << 5
const TRIGGER := 1 << 6
const BOSS := 1 << 7
const BARS := 1 << 8

## 挡光的墙，也是视线射线的 mask。
const WALLS := WORLD | CRACKED | MIRROR | PAD | VINE
## 挡小星的东西：所有墙加上栅栏。
const SOLID := WALLS | BARS
