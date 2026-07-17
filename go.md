# Go

Idiomatic Go, Effective Go + Google Go Style Guide. Correctness > any rule here; comment deviations.

## Philosophy

- Simple > clever. Read-time cost beats write-time cleverness — code read far more than written.
- Std lib first. Reach for third-party dep only when std lib genuinely lacks it; check `net/http`, `encoding/*`, `context`, `sync`, `slices`, `maps` before adding a module.
- A little duplication beats a wrong abstraction. Don't generalize on first repeat.
- Zero value useful where possible (`var buf bytes.Buffer` works with no init). Design types so zero value isn't a trap.

## Error Handling

- Wrap with context: `fmt.Errorf("do thing: %w", err)`. `%w` not `%v` — preserves chain for `errors.Is`/`errors.As`.
- Sentinel errors (`var ErrNotFound = errors.New("not found")`) for simple "which case" checks. Typed errors (`type ValidationError struct{...}`, implements `error`) when caller needs structured data back.
- Check with `errors.Is(err, ErrNotFound)` / `errors.As(err, &target)`, never string-match on `err.Error()`.
- No naked `return err` up a stack of more than one frame without adding context at the boundary that has it (function name, key input). Bubbling the exact same unwrapped error through 3+ layers loses where it happened.
- No `panic` outside `main`/`init`/truly-impossible invariant violations (e.g. hardcoded regex `MustCompile`). Library code returns errors; panic in a library is a bug, not a strategy.
- Don't ignore errors with `_`; if genuinely safe to ignore, comment why.

```go
func loadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("read config %s: %w", path, err)
    }
    var cfg Config
    if err := json.Unmarshal(data, &cfg); err != nil {
        return nil, fmt.Errorf("parse config %s: %w", path, err)
    }
    return &cfg, nil
}
```

## Package Layout

- `cmd/<binary>/main.go` per entrypoint — thin, wiring only (flags, config load, dependency construction, call into `internal`/lib).
- `internal/` for everything not meant as public API — compiler-enforced, not just convention. Default here unless deliberately exporting a library.
- No `util`/`common`/`helpers` dumping ground. Name package for what it provides (`validate`, `retry`, `parse`), not what it lacks a home for. Grab-bag package = missing abstraction.
- Package name = short, lowercase, no underscores, no stutter with its own exports (`http.Client` not `http.HTTPClient`).
- One import cycle rule: if two packages need each other, merge them or extract the shared piece into a third.

## Interfaces

- Define interface at the consumer (caller declares what it needs), not at the producer. Producer returns concrete struct.
- Keep small: 1-3 methods. `io.Reader`/`io.Writer`-sized, not god-interfaces. Compose via embedding when more is needed (`io.ReadWriter`).
- Accept interfaces, return structs: params take the narrowest interface that satisfies the call; return values are concrete types so callers get full API + can still assign to a local interface var if they want.
- Don't add an interface for a single production implementation "for testing" — table-driven tests + real struct usually suffice; introduce the interface when a second real implementation shows up or the boundary is genuinely external (DB, network).

## Context

- `context.Context` always first param, named `ctx`: `func Fetch(ctx context.Context, id string) (*Item, error)`.
- Propagate the incoming ctx through the call chain (derive with `context.WithTimeout`/`WithCancel`/`WithValue`, don't create a fresh `context.Background()` mid-chain unless deliberately detaching, e.g. fire-and-forget cleanup — comment why).
- Never store `context.Context` in a struct field. Pass explicitly per call; a stored ctx goes stale and hides the call graph.
- `context.WithValue` for request-scoped metadata only (trace id, auth principal) — never for optional params a function could just take directly.

## Concurrency

- Channels for ownership handoff / pipelines (one goroutine produces, another consumes). Mutex (`sync.Mutex`/`sync.RWMutex`) for protecting shared mutable state accessed by multiple goroutines without a clear producer/consumer shape. Don't reach for channels to protect a plain counter — that's a mutex job.
- Fan-out/fan-in work with known error surface: `golang.org/x/sync/errgroup`. Cancels sibling goroutines on first error, collects the real one.
- Every goroutine you start: know how it exits. No goroutine without a clear termination condition (ctx cancellation, channel close, WaitGroup) — a goroutine that "just runs" is a leak waiting to happen.
- `sync.WaitGroup` pairs `Add` before the goroutine starts, `Done` deferred inside it. `go func() { defer wg.Done(); ... }()`.
- Never send on a channel from inside a goroutine without a receiver guaranteed to exist (buffered channel sized right, or receiver started first) — unbuffered send with no listener deadlocks silently.

```go
func fetchAll(ctx context.Context, ids []string) ([]*Item, error) {
    g, ctx := errgroup.WithContext(ctx)
    items := make([]*Item, len(ids))
    for i, id := range ids {
        i, id := i, id
        g.Go(func() error {
            item, err := fetchOne(ctx, id)
            if err != nil {
                return fmt.Errorf("fetch %s: %w", id, err)
            }
            items[i] = item
            return nil
        })
    }
    if err := g.Wait(); err != nil {
        return nil, err
    }
    return items, nil
}
```

## Linting

- `golangci-lint` is the required linter. Repo `.golangci.yml` is source of truth for enabled linters/exclusions — don't hand-roll a different lint set per invocation.
- CI runs `golangci-lint run` and fails the build on any finding (`-D warnings` equivalent — no "warnings ok" tier).
- Scoped `//nolint:<linter> // reason` for genuine false positives; never a bare `//nolint` and never disable a linter repo-wide to silence one call site.

## Testing

- Table-driven tests in `_test.go` beside the code (`foo.go` → `foo_test.go`), package `foo` (white-box) or `foo_test` (black-box, exported API only) depending on what's under test.
- Subtests via `t.Run(name, func(t *testing.T) {...})` — one entry per table row, name describes the case, failures point at the exact row.
- NON-OPTIONAL: new or changed exported code gets tests in the same change. No "will add tests later."
- `testify` (`assert`/`require`) allowed: `require` when failure should stop the test immediately (setup, preconditions), `assert` when checking multiple independent outcomes in one test.
- `t.Parallel()` on subtests/tests that are independent and safe to interleave (no shared mutable fixture, no reliance on execution order).

```go
func TestParse(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int
        wantErr bool
    }{
        {name: "valid", input: "42", want: 42},
        {name: "empty", input: "", wantErr: true},
        {name: "non-numeric", input: "abc", wantErr: true},
    }
    for _, tt := range tests {
        tt := tt
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            got, err := Parse(tt.input)
            if tt.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

## Makefile

- Standard trio, same verbs every repo: `make build`, `make lint`, `make test`. Add more targets as needed (`make fmt`, `make run`) but keep these three present and doing what their name says.
- `lint` runs `golangci-lint run`; `test` runs `go test ./...` (add `-race` for anything touching goroutines/shared state); `build` runs `go build ./...` or produces the `cmd/` binaries.

## go.mod Hygiene

- Pin Go version in `go.mod` (`go 1.x`) to the CI-tested version — not a moving floor.
- `go mod tidy` before every commit that touches imports/deps. No stray `// indirect` drift, no unused requires committed.
- Commit `go.sum`. Small dep tree; audit new deps for maintenance/license before adding.

## Docs

- Every exported identifier (func, type, const, var, package) gets a godoc comment starting with the identifier's name, full sentence(s): `// Parse converts s into an int, returning an error if s is not numeric.`
- Package doc: `// Package foo does X.` as the first line of one file in the package (conventionally `doc.go` for larger packages).
- Comment explains *why*/non-obvious behavior/caller invariants, not a restatement of the signature.

## Checklist

- [ ] `golangci-lint run` clean per repo `.golangci.yml`
- [ ] `go test ./...` (+ `-race` if concurrent) passes
- [ ] New/changed exported code: godoc comment + table-driven test
- [ ] `go mod tidy` run, `go.sum` committed
- [ ] No naked panic outside main/init; errors wrapped with `%w` at each meaningful boundary
