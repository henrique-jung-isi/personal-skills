#!/usr/bin/env bash
# Builds the rate-service fixture: a small C++ repository on branch feature/limits with a dated
# history, plus the exported review of its pull request #42 in ./review/. Run it in an empty
# directory; it creates ./rate-service and ./review.
set -euo pipefail

root=$(pwd)
repo="$root/rate-service"
mkdir -p "$repo" "$root/review"
cd "$repo"
git init -q -b main
git config user.name "Fixture Author"
git config user.email "author@example.com"

commit() {
    local date=$1
    shift
    git add -A
    GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" git commit -q -m "$@"
}

mkdir -p src tests docs

cat > AGENTS.md <<'EOF'
# AGENTS.md — rate-service

C++20 service that samples a rate sensor, keeps a buffer of recent readings and drives output
channels. Code, comments and commit messages are in American English.

## Validation

Every code change must pass, in this order:

```bash
make format-check
make test
```

## Commit messages

Conventional Commits: `<type>(<scope>): <imperative summary>`, under 72 characters, no trailing
period. The body, when present, explains why, with bullets starting with `*`. Never add
co-author trailers.

## Rules

Read [docs/conventions.md](docs/conventions.md) before touching `src/`.
EOF

cat > docs/conventions.md <<'EOF'
# Conventions

- Use named structs or `std::optional` for outputs; no raw output parameters.
- Mark trivial getters `noexcept`.
EOF

cat > Makefile <<'EOF'
CXX ?= c++
CXXFLAGS ?= -std=c++20 -Wall -Wextra -Wno-missing-field-initializers -Werror -Isrc
SOURCES := $(wildcard src/*.cpp)

build/tests: $(SOURCES) tests/tests.cpp
	@mkdir -p build
	$(CXX) $(CXXFLAGS) $(SOURCES) tests/tests.cpp -o $@

test: build/tests
	./build/tests

format-check:
	@! grep -nP '\t' src/*.cpp src/*.h tests/*.cpp

.PHONY: test format-check
EOF

cat > .gitignore <<'EOF'
build/
EOF

cat > src/sample_buffer.h <<'EOF'
#pragma once

#include <cstddef>
#include <vector>

struct Sample {
    double time_s{};
    double value{};
};

// Keeps every reading of the current session in memory.
class SampleBuffer {
public:
    void add(const Sample& sample);
    [[nodiscard]] std::size_t entry_count() const noexcept { return samples_.size(); }

private:
    std::vector<Sample> samples_;
};
EOF

cat > src/sample_buffer.cpp <<'EOF'
#include "sample_buffer.h"

void SampleBuffer::add(const Sample& sample) { samples_.push_back(sample); }
EOF

cat > src/controller.h <<'EOF'
#pragma once

#include <cstddef>
#include <cstdint>
#include <span>
#include <vector>

// One restriction byte per output channel; one means the channel is held closed.
class Controller {
public:
    explicit Controller(std::size_t channels);
    void close_all() noexcept;
    void reset() noexcept;
    [[nodiscard]] std::span<const std::uint8_t> restrictions() const noexcept { return mask_; }

private:
    std::size_t channels_{};
    std::vector<std::uint8_t> mask_;
};
EOF

cat > src/controller.cpp <<'EOF'
#include "controller.h"

Controller::Controller(const std::size_t channels)
    : channels_{channels}, mask_(channels, 0U) {}

void Controller::close_all() noexcept { mask_ = std::vector<std::uint8_t>(channels_, 1U); }

void Controller::reset() noexcept { mask_ = std::vector<std::uint8_t>(channels_, 0U); }
EOF

cat > src/runtime.h <<'EOF'
#pragma once

#include "controller.h"

class Runtime {
public:
    explicit Runtime(std::size_t channels) : controller_{channels} {}
    // Called from the signal handler path and from the destructor of the service.
    void shutdown() noexcept;
    void emergency_stop() noexcept;
    [[nodiscard]] const Controller& controller() const noexcept { return controller_; }

private:
    Controller controller_;
};
EOF

cat > src/runtime.cpp <<'EOF'
#include "runtime.h"

void Runtime::shutdown() noexcept { controller_.reset(); }

void Runtime::emergency_stop() noexcept { controller_.close_all(); }
EOF

cat > src/parser.h <<'EOF'
#pragma once

#include <string_view>

// Parses a positive integer limit. Returns false when the text is not a valid limit.
bool parse_limit(std::string_view text, int& limit);
EOF

cat > src/parser.cpp <<'EOF'
#include "parser.h"

#include <charconv>

bool parse_limit(const std::string_view text, int& limit) {
    int value{};
    const auto [end, error] = std::from_chars(text.data(), text.data() + text.size(), value);
    if (error != std::errc{} || end != text.data() + text.size() || value <= 0) return false;
    limit = value;
    return true;
}
EOF

cat > tests/tests.cpp <<'EOF'
#include <cassert>
#include <cstdio>

#include "controller.h"
#include "parser.h"
#include "runtime.h"
#include "sample_buffer.h"

int main() {
    int limit{};
    assert(parse_limit("12", limit) && limit == 12);
    assert(!parse_limit("0", limit));
    assert(!parse_limit("x", limit));

    Runtime runtime{3U};
    runtime.emergency_stop();
    assert(runtime.controller().restrictions()[0] == 1U);
    runtime.shutdown();
    assert(runtime.controller().restrictions()[2] == 0U);

    SampleBuffer buffer;
    buffer.add({0.0, 1.0});
    assert(buffer.entry_count() == 1U);
    std::puts("all tests passed");
    return 0;
}
EOF

commit "2026-10-01T10:00:00-03:00" "feat: add sampling, controller and limit parser"

cat > docs/buffer-memory.md <<'EOF'
# Sample buffer memory

Workload: one reading every 10 ms, eight hours of continuous sampling.

| Duration | Entries | Memory |
| --- | --- | --- |
| 1 h | 360,000 | ~5.8 MB |
| 8 h | 2,880,000 | ~46 MB per channel |

With 96 channels the buffer reaches about **4.4 GB** after a working day, and nothing is ever
dropped.
EOF
commit "2026-10-05T16:00:00-03:00" "docs: measure sample buffer memory"

cat > src/sample_buffer.h <<'EOF'
#pragma once

#include <cstddef>
#include <optional>
#include <vector>

struct Sample {
    double time_s{};
    double value{};
};

// Summary of consecutive readings. A batch closes after k_batch_samples readings or
// k_batch_seconds, whichever comes first.
struct Batch {
    double start_s{};
    double end_s{};
    double min{};
    double max{};
    double sum{};
    std::size_t count{};
};

inline constexpr std::size_t k_batch_samples = 500U;
inline constexpr double k_batch_seconds = 30.0;

// Keeps the readings of the current session as closed batches plus the open one.
class SampleBuffer {
public:
    void add(const Sample& sample);
    [[nodiscard]] std::size_t entry_count() const noexcept {
        return batches_.size() + (open_.has_value() ? 1U : 0U);
    }

private:
    std::vector<Batch> batches_;
    std::optional<Batch> open_;
};
EOF

cat > src/sample_buffer.cpp <<'EOF'
#include "sample_buffer.h"

#include <algorithm>

void SampleBuffer::add(const Sample& sample) {
    if (!open_.has_value()) {
        open_ = Batch{sample.time_s, sample.time_s, sample.value, sample.value, 0.0, 0U};
    }
    auto& batch = *open_;
    batch.end_s = sample.time_s;
    batch.min = std::min(batch.min, sample.value);
    batch.max = std::max(batch.max, sample.value);
    batch.sum += sample.value;
    ++batch.count;
    if (batch.count >= k_batch_samples || batch.end_s - batch.start_s >= k_batch_seconds) {
        batches_.push_back(batch);
        open_.reset();
    }
}
EOF
commit "2026-10-12T09:30:00-03:00" "refactor(buffer): simplify sample storage"

git checkout -q -b feature/limits

cat > src/commands.h <<'EOF'
#pragma once

#include <optional>
#include <string>
#include <string_view>

struct Ack {
    bool status{};
    std::optional<int> limit;
    std::optional<std::string> mode;
};

// Session preferences set by the operator. Effective values are what the hardware applies.
class Commands {
public:
    explicit Commands(int safety_cap) : safety_cap_{safety_cap} {}

    [[nodiscard]] Ack set_mode(std::string_view mode);
    [[nodiscard]] Ack set_limit(std::string_view text);

    // Published on info/mode and info/limit.
    [[nodiscard]] std::string effective_mode() const;
    [[nodiscard]] int effective_limit() const noexcept;

    void set_interlock(bool engaged) noexcept { interlock_ = engaged; }

private:
    int safety_cap_{};
    int requested_limit_{100};
    std::string requested_mode_{"auto"};
    bool interlock_{};
};
EOF

cat > src/commands.cpp <<'EOF'
#include "commands.h"

#include <algorithm>

#include "parser.h"

Ack Commands::set_mode(const std::string_view mode) {
    if (mode != "auto" && mode != "manual") return Ack{.status = false};
    requested_mode_ = std::string{mode};
    return Ack{.status = true, .mode = requested_mode_};
}

Ack Commands::set_limit(const std::string_view text) {
    int limit{};
    if (!parse_limit(text, limit)) return Ack{.status = false};
    requested_limit_ = limit;
    return Ack{.status = true, .limit = requested_limit_};
}

std::string Commands::effective_mode() const { return interlock_ ? "manual" : requested_mode_; }

int Commands::effective_limit() const noexcept { return std::min(requested_limit_, safety_cap_); }
EOF

cat > docs/api.md <<'EOF'
# Command API

## set-mode

`{mode}` with `auto` or `manual`. The ACK `{status, mode}` returns the mode the operator chose,
which is kept for the session. While the interlock is engaged the hardware runs manually and
`info/mode` reports `manual`; the chosen mode applies again once the interlock is released.

## set-limit

`{limit}`, a positive integer. The ACK is `{status, limit}`. `info/limit` reports the limit in
force, clamped to the safety cap.
EOF

cat >> tests/tests.cpp <<'EOF'
EOF
python3 - <<'PY'
from pathlib import Path
p = Path("tests/tests.cpp")
s = p.read_text()
s = s.replace('#include "controller.h"\n', '#include "commands.h"\n#include "controller.h"\n')
s = s.replace('    std::puts("all tests passed");', '''    Commands commands{50};
    const auto limit_ack = commands.set_limit("80");
    assert(limit_ack.status && limit_ack.limit == 80);
    assert(commands.effective_limit() == 50);
    commands.set_interlock(true);
    const auto mode_ack = commands.set_mode("auto");
    assert(mode_ack.status && mode_ack.mode == "auto");
    assert(commands.effective_mode() == "manual");
    std::puts("all tests passed");''')
p.write_text(s)
PY
commit "2026-10-20T14:00:00-03:00" "feat(commands): add set-limit with a safety cap"

# A bare remote so pushes have a target but nothing leaves the machine.
git init -q --bare "$root/origin.git"
git remote add origin "$root/origin.git"
git push -q -u origin main feature/limits 2>/dev/null

cd "$root/review"
cat > pull-request.json <<'EOF'
{
  "number": 42,
  "title": "feat(commands): add set-limit with a safety cap",
  "url": "https://github.com/example/rate-service/pull/42",
  "headRefName": "feature/limits",
  "baseRefName": "main"
}
EOF

cat > reviews.json <<'EOF'
[
  {
    "author": "reviewer-ana",
    "state": "CHANGES_REQUESTED",
    "submittedAt": "2026-10-22T18:10:00Z",
    "body": "## Visão geral\n\nA API de limite está boa, mas há riscos de memória e de terminate no desligamento, e o ACK de `set-limit` não reflete o limite efetivo.\n\n**Achados:** 2 Alta · 1 Média · 1 Baixa\n\n- [Alta] Limitar a memória do buffer de amostras (discussion_r9001)\n- [Alta] `Controller::reset` é `noexcept` mas aloca (discussion_r9002)\n- [Média] Alinhar o ACK de `set-limit` com o limite efetivo (discussion_r9003)\n- [Baixa] Parâmetro de saída cru em `parse_limit` (discussion_r9004)"
  }
]
EOF

cat > conversation-comments.json <<'EOF'
[]
EOF

cat > inline-comments.json <<'EOF'
[
  {
    "id": 9001,
    "user": "reviewer-ana",
    "path": "src/sample_buffer.cpp",
    "line": 5,
    "created_at": "2026-10-22T18:10:00Z",
    "in_reply_to_id": null,
    "body": "**[Alta] Limitar a memória do buffer de amostras**\n\nCada leitura vira uma entrada e nada é descartado. A medição de `docs/buffer-memory.md` mostra ~4,4 GB depois de um dia com 96 canais, o que não cabe no alvo embarcado. Sugestão: trocar o buffer por um raster de tamanho fixo ou um ring buffer com teto, e documentar um orçamento de memória antes do merge."
  },
  {
    "id": 9002,
    "user": "reviewer-ana",
    "path": "src/controller.cpp",
    "line": 8,
    "created_at": "2026-10-22T18:10:00Z",
    "in_reply_to_id": null,
    "body": "**[Alta] `Controller::reset` é `noexcept` mas aloca**\n\n`reset()` e `close_all()` constroem um vetor novo; um `bad_alloc` ali vira `std::terminate`. Sugestão: remover o `noexcept` dessas funções."
  },
  {
    "id": 9003,
    "user": "reviewer-ana",
    "path": "src/commands.cpp",
    "line": 16,
    "created_at": "2026-10-22T18:10:00Z",
    "in_reply_to_id": null,
    "body": "**[Média] Alinhar o ACK de `set-limit` com o limite efetivo**\n\n`set-limit` com 80 devolve `limit: 80` no ACK, mas `info/limit` publica 50 por causa do teto de segurança. O HMI recebe sucesso com um valor que não vale. Sugestão: recusar limites acima do teto ou devolver o limite efetivo no ACK."
  },
  {
    "id": 9004,
    "user": "reviewer-ana",
    "path": "src/parser.h",
    "line": 6,
    "created_at": "2026-10-22T18:10:00Z",
    "in_reply_to_id": null,
    "body": "**[Baixa] Parâmetro de saída cru em `parse_limit`**\n\n`parse_limit(std::string_view, int&)` usa parâmetro de saída cru, o que `docs/conventions.md` proíbe. Sugestão: devolver `std::optional<int>`."
  }
]
EOF

cat > README.md <<'EOF'
# Exported review of pull request #42

GitHub is not reachable from this environment. These files are what `gh` would return:

- `pull-request.json` — the pull request (`gh pr view 42`).
- `reviews.json` — review bodies (`gh pr view 42 --json reviews`).
- `inline-comments.json` — inline review comments (`gh api repos/<o>/<r>/pulls/42/comments`).
- `conversation-comments.json` — conversation comments (`gh pr view 42 --json comments`).

The repository is `../rate-service`, already on branch `feature/limits`, with `origin` pointing at
a local bare repository. Anything that would publish to GitHub (pushing, commenting, resolving
threads, opening issues) must instead be written as a file in `../published/`, named after the
action, with the exact content that would be sent.
EOF
