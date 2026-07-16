# Rust

Idiomatic Rust + Rust API Guidelines. Correctness > any rule here; comment deviations.

## Philosophy

- Illegal states unrepresentable: constraints in type system (enums, newtypes), not runtime checks.
- Parse, don't validate: loose input → strong type once at boundary.
- Static zero-cost abstractions (iterators, generics, bounds) over `dyn` + allocation.
- Split by concern into small focused crates in a workspace (pure algorithm / I/O wrapper / CLI), not one monolith.

## Naming

RFC 430 casing. Prefix contracts (C-CONV): `as_` free borrow reinterpret; `to_` costly copy/compute; `into_` consumes self; `is_`/`has_`/`can_` predicates; single-value wrapper → `into_inner()`, never pub tuple field. **Getters: no `get_` prefix** — `fn name(&self)`, mutable variant `fn name_mut(&mut self)`. Setters: `set_name(&mut self, ...)`.

## Fields Private by Default

Pub fields only on invariant-free data records (config/DTO, clap derive structs); else private fields, constructor establishes invariant, methods expose behavior.

```rust
pub struct RateLimiter { tokens: f64, capacity: f64 }

impl RateLimiter {
    pub fn new(capacity: f64) -> Self { Self { tokens: capacity, capacity } }
    pub fn tokens(&self) -> f64 { self.tokens }
    #[must_use]
    pub fn try_consume(&mut self, cost: f64) -> bool { /* checks invariant */ }
}
```

- `Copy` returns by value; non-`Copy` by reference unless caller needs ownership.
- Setter that just assigns an invariant-bearing field = smell; fold into re-validating method.
- `#[must_use]` on nearly every pure-returning fn: constructors, getters, `to_*`/`into_*`.
- Invariant-free accessor boilerplate → `getset` derive. Many optional ctor params → builder (`typed-builder`/`derive_builder`).
- Newtype + `TryFrom` makes primitives misuse-proof: `struct Percentage(f64)`.

## Enums Over bool/String State

Domain-meaning `bool`/`&str` params → enums; call site must read like the decision:

```rust
fn connect(&self, retry: RetryPolicy, transport: Transport) -> Result<Connection, ConnectError>
// not: fn connect(&self, retry: bool, secure: bool)
```

State machines = enum, variants carry exactly the data valid per state — not `status: String` + sometimes-populated `Option<T>` fields:

```rust
enum JobState {
    Pending,
    Running { started_at: Instant, worker: WorkerId },
    Done { output: Output },
    Failed { error: JobError, retriable: bool },
}
```

Growth-expected pub enums/structs: `#[non_exhaustive]`. Default variant: `#[derive(Default)]` + `#[default]` attr, not hand-written impl.

## Traits

- Shared behavior → trait w/ default methods; implementors supply only the minimal required set.
- Static dispatch for lib APIs + hot paths; `dyn` only for genuine runtime polymorphism.
- C-COMMON-TRAITS: `Debug` on every pub type; `Default`/`Clone`/`Eq`/`Hash`/`Display` where sensible; `From`/`TryFrom` over bespoke conversion fns.
- Blanket-impl for refs: `impl<T: Trait> Trait for &T {}` + `&mut` equivalent.
- Extension traits for foreign types; sealed pattern (private supertrait) for closed traits.

## Macros

For repeated impl *shape* across types — one `macro_rules!` splicing a body into several `impl Trait for X` blocks beats near-duplicate impls. Prefer established derives (`thiserror`, `derive_more`, `strum`, `getset`) over hand-rolled proc macros. Macro hiding control flow or needing own tests = obfuscation; use fn/generic. Generics abstract types; macros collapse syntax — don't confuse the two.

## Errors

- Crate-wide `Error` enum (`thiserror`) + small scoped enums per fallible conversion; no mega-enum.
- `#[error(transparent)]` for pure wrappers; messages lowercase, terse, no trailing punctuation.
- Binaries may propagate lib `Error` straight to print boundary; `anyhow` only when aggregating many unrelated sources; never in lib pub API.
- `unwrap`/`expect`: locally proven invariants + tests only, never I/O/user-input/config paths. `expect` msg names the failed action.
- `?` always; `match` forwarding `Ok`/`Err` unchanged = `?` in disguise.

## Ownership & Signatures

- Accept least specific: `&str`, `&[T]`, `impl AsRef<Path>`.
- Return borrows tied to `&self` where possible.
- Borrow-checker-appeasing `.clone()` = restructure signal, not a fix.
- `impl Trait` arg for one bound; named generic + `where` once bounds multiply.
- Pick one mutation style per type: immutable core (consume/return new) or fluent `&mut self -> &mut Self` wrapper.

## Performance

- Measure first: `criterion` benchmarks, profiler (`flamegraph`/`perf`/`samply`) for hot paths. No before/after number = guess.
- Allocate once, reuse: `with_capacity` when size known, scratch buffer `clear()`+refill across iterations. Biggest hot-loop lever.
- Iterator chains over clone + manual indexing — fewer bounds checks, better vectorization.
- CPU-bound algorithms: runtime hw-acceleration dispatch (`cpufeatures`/`std::arch`) + portable scalar fallback.
- `#[inline]` only small hot cross-crate fns, profiler-justified. `const fn` on const-evaluable ctors/getters.
- Hot compute stays sync; `async` only at I/O boundary.
- `unsafe` for perf = last resort: benchmark-gated + `// SAFETY:` comment.

## Concurrency

- Message passing over shared state (workers → `mpsc` → single consumer thread); `Arc<Mutex/RwLock>` only when channels more awkward.
- Never hold lock guard across `.await`.
- Native `async fn` in traits = default; not `dyn`-compatible — box future or `async-trait` for trait objects; `#[trait_variant::make]` for Send bounds on multithreaded runtimes.

## Modules

- One responsibility per module; `foo/mod.rs`, not flat `foo.rs` beside `foo/`. `lib.rs`/`main.rs` = wiring only.
- Private `mod x;` + explicit `pub use x::{Y};` — re-exports define the API surface.
- Multi-binary: workspace, shared `-core` lib, thin binaries. Optional pieces behind Cargo features named after what they enable.
- Internal `use` targets the module that *defines* the item (`use crate::error::Result;`), not a re-export or intermediate `pub use` (`use crate::Result;`) — re-exports exist for external callers, not to shortcut your own `use` lines. Crate-root-defined items (consts, free fns actually written in `lib.rs`) are the exception: importing them as `crate::THING` already is the defining path.

## Testing & CI

- Unit: `#[cfg(test)] mod tests` beside code, no `test_` prefix. Integration: `tests/`, pub API only, all accepted input types; names `{entry_point}_{scenario}`.
- Fuzz targets (cargo-fuzz + `arbitrary` behind `fuzzing` feature) for algorithmic/parsing crates.
- Benchmarks: `criterion`.
- CI: lint job (fmt + clippy) gates test matrix OS × {MSRV, stable, nightly}; trigger paths filtered to `src/**`, `tests/**`, `Cargo.toml`.

## Docs

- Line 1: one short plain sentence, what item does/returns. Longer prose only for non-obvious behavior, caller invariants, perf notes, *why*.
- Two readers: skimming human + zero-context LLM. Explicit subjects (no dangling "it"), explicit units + ownership, fixed headers `# Examples`/`# Errors`/`# Panics`/`# Safety`.
- Crate root `//!`: summary → `# Setup` → usage → `# License`. Every module: `//!` + ≥1 example.
- Every pub item: runnable `# Examples` ending in concrete `assert_eq!`; hide setup w/ `# `; must pass `cargo test --doc`.

## Lints, Format, Unsafe

Committed `rustfmt.toml`:

```toml
max_width = 120
group_imports = "StdExternalCrate"
hex_literal_case = "Upper"
use_field_init_shorthand = true
match_block_trailing_comma = true
```

- `#[rustfmt::skip]` ok on hand-aligned constant tables; never to dodge lints.
- Clippy in CI, `--all-targets --all-features`; deny ≥ `clippy::cargo`, prefer `-D warnings`. Scoped `#[allow]` + reason; crate-root `#[allow]` only for genuinely crate-wide lints.
- `#![forbid(unsafe_code)]` default. Unavoidable `unsafe`: isolated module + `// SAFETY:` per block.

## Cargo

- MSRV (`rust-version`) pinned per crate to CI-tested value.
- Crates.io readme at `.cargo/README.md`, separate from repo-root README.
- docs.rs: `all-features = true` + `--cfg docsrs` + `doc_auto_cfg` for feature badges. Fill `keywords`/`categories`.
- `CHANGELOG.md`: Keep a Changelog + SemVer, compare-links, even at `0.0.x`.
- Commit `Cargo.lock` for binaries. Small dep tree; `cargo audit` in CI. Workspace at >1 crate; versions in `[workspace.dependencies]`.

## Checklist

- [ ] fmt + clippy clean; `cargo test` + `--doc` pass
- [ ] New pub items: doc + runnable example
- [ ] New pub fields / `unwrap` outside tests: justified in comment
- [ ] Perf claims: before/after benchmark
