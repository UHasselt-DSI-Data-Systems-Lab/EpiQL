# Built-in types

Every column of a relation has a type, which says what values it can hold. These types are
built into EpiQL:

## Integers

| Type | Smallest value | Largest value |
| --- | --- | --- |
| `u8` | 0 | 255 |
| `u16` | 0 | 65 535 |
| `u32` | 0 | 4 294 967 295 (about 4.3 × 10⁹) |
| `u64` | 0 | 18 446 744 073 709 551 615 (about 1.8 × 10¹⁹) |
| `i8` | −128 | 127 |
| `i16` | −32 768 | 32 767 |
| `i32` | −2 147 483 648 | 2 147 483 647 (about 2.1 × 10⁹) |
| `i64` | −9 223 372 036 854 775 808 | 9 223 372 036 854 775 807 (about 9.2 × 10¹⁸) |

The `u` types (*unsigned*) hold only zero and positive integers; the `i` types hold negative
ones too. The number is the number of bits a value takes: `u8` takes 8 bits, `u64` takes 64.

## Real numbers

| Type | Precision | Largest value |
| --- | --- | --- |
| `f32` | about 7 significant digits | about 3.4 × 10³⁸ |
| `f64` | about 15 to 16 significant digits | about 1.8 × 10³⁰⁸ |

These are the IEEE 754 single (`f32`) and double (`f64`) precision floating-point numbers.

## Other built-in types

| Type | Values |
| --- | --- |
| `bool` | `true` and `false` |
| `time` | a timestep of the simulation |

## Which one to choose

A smaller type takes less memory, which matters for a population of millions. In the models in
this tutorial:

- person and household numbers are `u32`, which is enough for every person in a country;
- ages are `u8`;
- probabilities are `f64`.

In a calculation or a comparison you can mix types: a `u8` age can be compared with a `u32`
household number, or multiplied by `0.5`. But a value that a rule puts into a column must
have exactly the type of that column: a rule cannot put a `u8` age into a `u32` column, or the
other way round.

